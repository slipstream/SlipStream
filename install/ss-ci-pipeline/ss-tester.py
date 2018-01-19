#!/usr/bin/env python

import os
import json
import tarfile
import subprocess
import shutil
import collections

from slipstream.ConfigHolder import ConfigHolder
from slipstream.Client import Client
from slipstream.HttpClient import HttpClient
from slipstream.util import (download_file, fileAppendContent,
                             filePutContent, execute, importETree)

etree = importETree()

NAGIOS_STATUS_URL = 'http://monitor.sixsq.com/nagios/statusJson.php'
SS_SERVICES_IN_NAGIOS = ['nuv.la']

GIT_CREDS_URL = 'http://nexus.sixsq.com/service/local/repositories/releases-enterprise/content/' \
                'com/sixsq/slipstream/sixsq-hudson-creds/1.0.0/sixsq-hudson-creds-1.0.0.tar.gz'

SSH_DIR = os.path.expanduser('~/.ssh')


def ss_get(param, ignore_abort=False, timeout=30, no_block=False):
    """Returns None if parameter is not set.
    Raises Exceptions.NotFoundError if parameter doesn't exist.
    """
    ch = ConfigHolder(config={'foo': None})
    ch.set('ignoreAbort', ignore_abort)
    ch.set('no_block', no_block)
    ch.set('timeout', timeout)
    client = Client(ch)
    return client.getRuntimeParameter(param)


def ss_set(key, value, ignore_abort=False):
    ch = ConfigHolder(config={'foo': None})
    ch.set('ignoreAbort', ignore_abort)
    client = Client(ch)
    client.setRuntimeParameter(key, value)


def ss_display(msg, ignore_abort=False):
    ss_set('statecustom', msg, ignore_abort=ignore_abort)


def _print(msg):
    ss_display(msg)
    print('::: %s' % msg)


def _expanduser(path):
    return os.path.expanduser(path)


def _cd_home():
    os.chdir(_expanduser('~'))


def _cd(path):
    os.chdir(path)


def _mkdir(path, mode):
    path = os.path.expanduser(path)
    if not os.path.exists(path):
        os.makedirs(path)
        os.chmod(path, mode)


def _rmdir(path, ignore_errors=True):
    shutil.rmtree(path, ignore_errors=ignore_errors)


def _chown(path, uid, gid, recursive=False):
    if not recursive:
        os.chown(path, uid, gid)
    else:
        for root, dirs, files in os.walk(path):
            for d in dirs:
                os.chown(os.path.join(root, d), uid, gid)
            for f in files:
                os.chown(os.path.join(root, f), uid, gid)


def _tar_extract(tarball, target_dir='.'):
    tarfile.open(tarball, 'r:gz').extractall(os.path.expanduser(target_dir))


def _check_call(cmd):
    subprocess.check_call(cmd, stdout=subprocess.PIPE)


def _install_git_creds(nexus_user, nexus_pass):
    tarball = _expanduser('~/git-creds.tgz')
    download_file(GIT_CREDS_URL, tarball, creds={'username': nexus_user,
                                                 'password': nexus_pass})
    _mkdir(SSH_DIR, 0700)
    _tar_extract(tarball, SSH_DIR)
    os.unlink(tarball)

    ssh_conf = _expanduser(os.path.join(SSH_DIR, 'config'))
    fileAppendContent(ssh_conf, "Host github.com\n\tStrictHostKeyChecking no\n")
    os.chmod(ssh_conf, 0644)

    _chown(SSH_DIR, os.getuid(), os.getgid(), recursive=True)


def _install_ss_repo_creds_boot(nexus_user, nexus_pass):
    conf = """
(configure-repositories!
 (fn [{:keys [url] :as repo-map}]
   (->> (condp re-find url
          #"^http://nexus\.sixsq\.com/"
          {:username "%(user)s"
           :password "%(pass)s"}
          #".*" nil)
        (merge repo-map))))
""" % {'user': nexus_user, 'pass': nexus_pass}
    fileAppendContent(_expanduser('~/.boot/profile.boot'), conf)


def merge_dicts(x, y):
    z = x.copy()
    z.update(y)
    return z


def _get_test_user_pass():
    username = (ss_get('ss_test_user', no_block=True) or 'test').strip()
    users_passes = ss_get('ss_users')
    userpass = 'tesTtesT'
    if users_passes:
        # Comma separated list of colon separated user:pass pairs.
        userpass = dict(map(lambda x: x.split(':'), users_passes.split(','))).get(username, userpass)
    return username, userpass


def _get_monitoring_status():
    "Returns monitoring status as JSON."
    nagios_user, nagios_pass = ss_get('nagios_creds').split(':')

    h = HttpClient(username=nagios_user, password=nagios_pass)
    _, res = h.get(NAGIOS_STATUS_URL, accept="application/json")
    return json.loads(res)


def _check_enabled(check):
    return int(check.get('active_checks_enabled')) == 1


def _check_error(check):
    return int(check.get('current_state', 10)) > 0


def _enabled_and_error(check):
    return _check_enabled(check) and _check_error(check)


def _failing_monitored_connectors(ss_servers):
    "ss_servers - list of SS server names as defined in monitoring app."

    status = _get_monitoring_status()

    ss_exec_checks_err = {}
    for s in ss_servers:
        for chn, ch in status.get("services", {}).get(s, {}).items():
            if chn.startswith('ss-exec_') and _enabled_and_error(ch):
                if ss_exec_checks_err.has_key(chn):
                    _ch = ss_exec_checks_err.get(chn)
                    if int(_ch.get('last_check', 0)) < int(ch.get('last_check', 0)):
                        ss_exec_checks_err[chn] = ch
                else:
                    ss_exec_checks_err[chn] = ch
    return map(lambda x: x.replace('ss-exec_', ''), ss_exec_checks_err.keys())


def _get_connectors_to_test(monitored_ss):
    # Space separated list.
    requested = ss_get('connectors_to_test').split(' ')
    _print('Connectors requested to test: %s' % requested)
    monitored_failing = _failing_monitored_connectors(monitored_ss)
    _print('Connectors currently failing: %s on %s' % (monitored_failing, monitored_ss))
    return list(set(requested) - set(monitored_failing))


def _tests_to_run():
    return filter(None,
                  (ss_get('tests_to_run', no_block=True) or '').strip().split(';'))


class TestsRunner(object):
    """
    Order in which tests get added with add_test() is preserved.
    """

    def __init__(self, config_auth):
        self._tests = collections.OrderedDict()
        self._config_auth = config_auth
        self.failed_tests = []

    def add_test(self, name, config={}, connectors=[], msg='', fail=False):
        self._tests[name] = {'config': merge_dicts(self._config_auth, config),
                             'connectors': connectors,
                             'msg': msg,
                             'fail': fail}

    def get_test_names(self):
        return self._tests.keys()

    def run(self, tests_to_run=[]):
        testnames = tests_to_run or self.get_test_names()

        for name in testnames:
            self._run_test(name, **self._tests[name])

    def _run_test(self, tname, config={}, connectors=[], msg='', fail=False):
        if connectors:
            for connector in connectors:
                self._print_t(' '.join(filter(None, [msg, 'Connector: %s' % connector])))
                config['connectors'] = connector
                self.__run_test(tname, config=config, fail=fail)
        else:
            if msg:
                self._print_t(msg)
            self.__run_test(tname, config=config, fail=fail)

    def __run_test(self, name, config={}, fail=False):
        cmd = ['make', name, "TESTOPTS=%s" % self._build_test_opts(config)]
        print('executing: %s ' % cmd)
        rc = execute(cmd)
        if rc != 0:
            self.failed_tests.append((name, config.get('connectors', '')))
            if fail:
                raise Exception('Failed running test: %s' % name)

    def get_failed_tests(self):
        def _test_to_str(tpl):
            return '%s%s' % (tpl[0], (tpl[1] != '') and (' on ' + tpl[1]) or '')
        return map(_test_to_str, self.failed_tests)

    @staticmethod
    def _build_test_opts(config):
        opts = ""
        for k, v in config.items():
            if k not in ['insecure?']:
                opts += ' --%s %s' % (k, v)
        if config.get('insecure?', False):
            opts += ' -i'
        return opts

    @staticmethod
    def _print(msg):
        ss_display(msg)
        print(msg)

    @staticmethod
    def _print_t(msg):
        _print(':t: %s' % msg)

    def info(self):
        _print('Tests to run: %s' % self.get_test_names())


##
## Tests.
##

test_repo_branch = ss_get('test_repo_branch')
run_comp_uri = ss_get('run_comp_uri')
scale_app_uri = ss_get('scale_app_uri')
scale_comp_name = ss_get('scale_comp_name')
tests_to_run = _tests_to_run()

nexus_user, nexus_pass = ss_get('nexus_creds').split(':')

_print('Installing git credentials.')
_install_git_creds(nexus_user, nexus_pass)

_print('Install SS repo credentials for boot.')
_install_ss_repo_creds_boot(nexus_user, nexus_pass)

_cd_home()

_print('Cloning test repo.')
test_repo_name = 'SlipStreamTests'
_rmdir(_expanduser('~/%s' % test_repo_name), ignore_errors=True)
_check_call(['git', 'clone', 'git@github.com:slipstream/%s.git' % test_repo_name])

#
# Wait for deployer to deploy SlipStream.
ss_get('deployer.ready', timeout=2700)

test_username, test_userpass = _get_test_user_pass()

endpoint = ss_get('ss_service_url')

_print('Ready to run tests on %s as %s.' % (endpoint, test_username))

connectors_to_test = _get_connectors_to_test(SS_SERVICES_IN_NAGIOS)

_cd(test_repo_name)
_check_call(['git', 'checkout', test_repo_branch])

results_dir = _expanduser('~/test-results')
_rmdir(results_dir)
_mkdir(results_dir, 0755)

config_auth = {'username': test_username,
               'password': test_userpass,
               'endpoint': endpoint,
               'insecure?': True,
               'results-dir': results_dir}

tr = TestsRunner(config_auth)

# smoke test
tr.add_test('test-clojure-deps',
            msg='Check if local dependencies are available.', fail=True)

tr.add_test('test-auth',
            msg='Authentication tests on %s as %s.' % (endpoint, test_username))
#tr.add_test('test-run-comp',
#            msg='Component deployment - %s on %s as %s.' % (run_comp_uri, endpoint, test_username),
#            config={'comp-uri': run_comp_uri},
#            connectors=connectors_to_test)
#tr.add_test('test-run-app',
#            msg='Application deployment - %s on %s as %s.' % (scale_app_uri, endpoint, test_username),
#            config={'app-uri': scale_app_uri, 'comp-name': scale_comp_name},
#            connectors=connectors_to_test)
#tr.add_test('test-run-app-scale',
#            msg='Scalable deployment - %s on %s as %s.' % (scale_app_uri, endpoint, test_username),
#            config={'app-uri': scale_app_uri, 'comp-name': scale_comp_name},
#            connectors=connectors_to_test)

tr.info()

os.environ['BOOT_AS_ROOT'] = 'yes'
tr.run(tests_to_run=tests_to_run)

_print('All tests were ran.')

if tr.failed_tests:
    _print('Tests failed: %s' % ', '.join(tr.get_failed_tests()))
    exit(1)

