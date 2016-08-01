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


NAGIOS_STATUS_URL = 'http://monitor.sixsq.com/nagios/cgi-bin/statusJson.php'
SS_SERVICES_IN_NAGIOS = ['nuv.la', 'bb.sixsq.com']

GIT_CREDS_URL = 'http://nexus.sixsq.com/service/local/repositories/releases-enterprise/content/' \
                'com/sixsq/slipstream/sixsq-hudson-creds/1.0.0/sixsq-hudson-creds-1.0.0.tar.gz'

SSH_DIR = os.path.expanduser('~/.ssh')


def ss_get(param, ignore_abort=False, timeout=30, no_block=False):
    ch = ConfigHolder(config={'foo': None})
    ch.set('ignoreAbort', ignore_abort)
    ch.set('noBlock', no_block)
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


def _dict_to_edn(_dict):
    "Only string, boolean and None are fully supported."
    def _kv_to_edn(kv):
        k = kv[0]; v = kv[1]
        if isinstance(v, bool):
            return ' :%s %s' % (k, str(v).lower())
        elif v == None:
            return ' :%s nil' % k
        else:
            return ' :%s "%s"' % (k, v)
    return "{\n%s\n}" % '\n'.join(map(_kv_to_edn, _dict.items()))


def _get_test_user_pass():
    username = ss_get('ss_test_user', no_block=True).strip() or 'test'
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
        for chn,ch in status.get("services", {}).get(s, {}).items():
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


class TestsRunner(object):
    """
    Order in which tests get added with add_test() is preserved.
    """

    def __init__(self, config_auth, tests_loc, final_tests_loc, connectors_to_test=[]):
        self._tests = collections.OrderedDict()
        self._config_auth = config_auth
        self._tests_loc = tests_loc
        self._final_tests_loc = final_tests_loc
        self._connectors_to_test = connectors_to_test

    def add_test(self, name, config={}, connectors=[], msg='', fail=False, save_results=True):
        self._tests[name] = {'config': merge_dicts(self._config_auth, config),
                             'connectors': connectors or self._connectors_to_test,
                             'msg': msg,
                             'fail': fail,
                             'save_results': save_results}

    def get_test_names(self):
        return self._tests.keys()

    def run(self, tests_to_run=[]):
        testnames = tests_to_run or self.get_test_names()

        for name in testnames:
            self._run_test(name, **self._tests[name])

    def _run_test(self, tname, config={}, connectors=[], msg='', fail=False, save_results=True):
        if connectors:
            for connector in connectors:
                self._print_t(' '.join(filter(None, [msg, 'Connector: %s' % connector])))
                config['connector-name'] = connector
                self.__run_test(tname, config=config, fail=fail)
                if save_results:
                    self._save_result(tname, connector)
        else:
            if msg:
                self._print_t(msg)
            self.__run_test(tname, config=config, fail=fail)
            if save_results:
                self._save_result(tname)

    def __run_test(self, name, config={}, fail=False):
        if config:
            self._write_test_config(config)
        cmd = ['make', name]
        print('executing: %s ' % cmd)
        rc = execute(cmd)
        if fail and rc != 0:
            raise Exception('Failed running test: %s' % name)

    @staticmethod
    def _change_test_name_in_test_files(files_loc, connector):
        for fn in os.listdir(files_loc):
            if fn.endswith(".xml"):
                fn = os.path.join(files_loc, fn)
                tsuites = etree.parse(fn).getroot()
                for tsuite in tsuites.findall('testsuite'):
                    tsuite.set('package', connector + '.' + tsuite.attrib['package'])
                    for tcase in tsuite.findall('testcase'):
                        tcase.set('classname', connector + '.' + tcase.attrib['classname'])
                filePutContent(fn, etree.tostring(tsuites))

    def _save_result(self, name, connector=None):
        if connector:
            self._change_test_name_in_test_files(self._tests_loc, connector)
        shutil.move(self._tests_loc,
                    os.path.join(self._final_tests_loc,
                                 '%s%s' % (name, '-' + connector if connector else '')))

    @staticmethod
    def _write_test_config(config):
        filePutContent('clojure/resources/test-config.edn', _dict_to_edn(config))

    @staticmethod
    def _print(msg):
        ss_display(msg)
        print(msg)

    @staticmethod
    def _print_t(msg):
        _print(':t: %s' % msg)

    def info(self):
        _print('Connectors to test: %s' % self._connectors_to_test)
        _print('Tests to run: %s' % self.get_test_names())


##
## Tests.
##

test_repo_branch = ss_get('test_repo_branch')
run_comp_uri = ss_get('run_comp_uri')
scale_app_uri = ss_get('scale_app_uri')
scale_comp_name = ss_get('scale_comp_name')
tests_to_run = filter(None, ss_get('tests_to_run', no_block=True).strinp().split(';'))

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

ss_serviceurl = ss_get('ss_service_url')

_print('Ready to run tests on %s as %s.' % (ss_serviceurl, test_username))

connectors_to_test = _get_connectors_to_test(SS_SERVICES_IN_NAGIOS)

_cd(test_repo_name)
_check_call(['git', 'checkout', test_repo_branch])

final_tests_loc = _expanduser('~/test-results')
_rmdir(final_tests_loc)
_mkdir(final_tests_loc, 0755)

config_auth = {'username': test_username,
               'password': test_userpass,
               'serviceurl': ss_serviceurl,
               'insecure?': True}

tests_loc = 'clojure/target'

tr = TestsRunner(config_auth, tests_loc, final_tests_loc,
                 connectors_to_test=connectors_to_test)

tr.add_test('test-clojure-deps',
            msg='Check if local dependencies are available.',
            fail=True, save_results=False)
tr.add_test('test-auth',
            msg='Authentication tests on %s as %s.' % (ss_serviceurl, test_username))
tr.add_test('test-run-comp',
            msg='Component deployment - %s on %s as %s.' % (run_comp_uri, ss_serviceurl, test_username),
            config={'comp-uri': run_comp_uri})
tr.add_test('test-run-app',
            msg='Application deployment - %s on %s as %s.' % (scale_app_uri, ss_serviceurl, test_username),
            config={'app-uri': scale_app_uri, 'comp-name': scale_comp_name})
tr.add_test('test-run-app-scale',
            msg='Scalable deployment - %s on %s as %s.' % (scale_app_uri, ss_serviceurl, test_username),
            config={'app-uri': scale_app_uri, 'comp-name': scale_comp_name})

tr.info()

os.environ['BOOT_AS_ROOT'] = 'yes'
tr.run(tests_to_run=tests_to_run)

_print('All tests were ran.')

