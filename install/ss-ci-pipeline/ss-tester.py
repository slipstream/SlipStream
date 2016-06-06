#!/usr/bin/env python

import os
import tarfile
import subprocess
import shutil
import collections

import urllib2

from slipstream.ConfigHolder import ConfigHolder
from slipstream.Client import Client
from slipstream.util import (fileAppendContent,
                             filePutContent, execute)

GIT_CREDS_URL = 'http://nexus.sixsq.com/service/local/repositories/releases-enterprise/content/' \
                'com/sixsq/slipstream/sixsq-hudson-creds/1.0.0/sixsq-hudson-creds-1.0.0.tar.gz'


def download_file(src_url, dst_file, creds={}):
    """creds: {'cookie': '<cookie>',
               'username': '<name>', 'password': '<pass>'}
    cookie is preferred over username and password. If none are provided,
    the download proceeds w/o authentication.
    """
    request = urllib2.Request(src_url)
    if creds.get('cookie'):
        request.add_header('cookie', creds.get('cookie'))
    elif creds.get('username') and creds.get('password'):
        request.add_header('Authorization',
                           (b'Basic ' + (creds.get('username') + b':' + creds.get('password')).encode('base64')).replace('\n', ''))
    src_fh = urllib2.urlopen(request)

    dst_fh = open(dst_file, 'wb')
    while True:
        data = src_fh.read()
        if not data:
            break
        dst_fh.write(data)
    src_fh.close()
    dst_fh.close()

    return dst_file


def ss_get(param, ignore_abort=False, timeout=30):
    ch = ConfigHolder(config={'foo': None})
    ch.set('ignoreAbort', ignore_abort)
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
    print(msg)


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


def _install_git_creds():
    _print('Installing git credentials.')

    n_user, n_pass = ss_get('nexus_creds').split(':')

    tarball = _expanduser('~/git-creds.tgz')
    download_file(GIT_CREDS_URL, tarball, creds={'username': n_user,
                                                 'password': n_pass})
    ssh_dir = _expanduser('~/.ssh')
    _mkdir(ssh_dir, 0700)
    _tar_extract(tarball, ssh_dir)
    os.unlink(tarball)

    ssh_conf = _expanduser('~/.ssh/config')
    fileAppendContent(ssh_conf, "Host github.com\n\tStrictHostKeyChecking no\n")

    _chown(ssh_dir, os.getuid(), os.getgid(), recursive=True)


def merge_dicts(x, y):
    z = x.copy()
    z.update(y)
    return z


def _dict_to_edn(_dict):
    return "{\n%s\n}" % \
           '\n'.join(map(lambda kv: ' :%s "%s"' % (kv[0], kv[1]), _dict.items()))


def _write_test_config(config):
    filePutContent('clojure/resources/test-config.edn', _dict_to_edn(config))


def _run_test(name, config={}, fail=False):
    if config:
        _write_test_config(config)
    cmd = ['make', name]
    rc = execute(cmd)
    if fail and rc != 0:
        raise Exception('Failed running test: %s' % name)


def run_test(name, config={}, msg='', connectors=[], fail=False, save_results=True):
    if connectors:
        for connector in connectors:
            if msg:
                _print('::: %s' % (msg % {'connector': connector}))
            config['connector-name'] = connector
            _run_test(name, config=config, fail=fail)
            if save_results:
                shutil.move('clojure/target',
                            os.path.join(test_results_dir, '%s-%s' % (name, connector)))
    else:
        if msg:
            _print('::: %s' % msg)
        _run_test(name, config=config, fail=fail)
        if save_results:
            shutil.move('clojure/target', os.path.join(test_results_dir, name))


test_repo_branch = ss_get('test_repo_branch')
run_comp_uri = ss_get('run_comp_uri')
scale_app_uri = ss_get('scale_app_uri')
scale_comp_name = ss_get('scale_comp_name')

_install_git_creds()

_cd_home()

test_repo_name = 'SlipStreamTests'
_rmdir(_expanduser('~/%s' % test_repo_name), ignore_errors=True)
_check_call(['git', 'clone', 'git@github.com:slipstream/%s.git' % test_repo_name])

#
# Wait for deployer to deploy SlipStream.
#
ss_get('deployer.ready', timeout=2700)

users_passes = ss_get('ss_users')
test_username = 'test'
test_userpass = dict(map(lambda x: x.split(':'), users_passes.split(','))).get(test_username, 'tesTtesT')

ss_serviceurl = ss_get('ss_service_url')

_print('Ready to run tests on %s as %s.' % (ss_serviceurl, test_username))

connectors_to_test = ss_get('connectors_to_test')

_cd(test_repo_name)
_check_call(['git', 'checkout', test_repo_branch])

test_results_dir = _expanduser('~/test-results/')
_rmdir(test_results_dir)
_mkdir(test_results_dir, 0755)

config_auth = {'username': test_username,
               'password': test_userpass,
               'serviceurl': ss_serviceurl}

tests_no_order = {
    'test-run-comp': {
        'msg': 'Running component deployment tests of %s on %s as %s for connector: %s' %
               (run_comp_uri, ss_serviceurl, test_username, '%(connector)s'),
        'config': merge_dicts(config_auth, {'comp-uri': run_comp_uri}),
        'connectors': connectors_to_test},

    'test-run-app':
        {'msg': 'Running application deployment tests of %s on %s as %s for connector: %s' %
                (run_comp_uri, ss_serviceurl, test_username, '%(connector)s'),
         'config': merge_dicts(config_auth, {'app-uri': scale_app_uri}),
         'connectors': connectors_to_test},

    'test-run-app-scale':
        {'msg': 'Running scalable deployment tests of %s on %s as %s for connector: %s' %
                (run_comp_uri, ss_serviceurl, test_username, '%(connector)s'),
         'config': merge_dicts(config_auth, {'app-uri': scale_app_uri,
                                             'comp-name': scale_comp_name}),
         'connectors': connectors_to_test},
}

tests = collections.OrderedDict(
        [('test-clojure-deps', {'msg': 'Check if local dependencies are available.',
                                'fail': True,
                                'save_results': False}),

         ('test-auth', {'msg': 'Running authentication tests on %s as %s.' % (ss_serviceurl, test_username),
                        'config': config_auth})] +

        tests_no_order.items()
)

os.environ['BOOT_AS_ROOT'] = 'yes'

for name, params in tests.items():
    run_test(name, **params)

_print('All tests were ran.')
