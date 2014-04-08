#!/usr/bin/env python

import optparse
import re
import sys
import unittest

snapshotPostfix = '-SNAPSHOT'
project_version_re = re.compile('(<version>)(.*)(</version>)')
slipstream_version_re = re.compile('(<slipstream\.version>)([a-zA-Z0-9.-]+)(</slipstream\.version>)')


class Pom(object):

    def __init__(self):
        self.release = False
        self.project = False

    def replace_version(self):
        with open(self.pom) as f:
            if self.project:
                newLines = self._process_project_version(f)
            else:
                newLines = self._process_slipstream_version(f)
            open(self.pom, 'w').writelines(newLines)

    def _process_project_version(self, fileHandler):
        foundParent = False
        newLines = []
        for line in fileHandler:
            if foundParent:
                newLines.append(self._replaceIfFound(project_version_re, line))
            else:
                newLines.append(line)
                if not foundParent and '<parent>' in line:
                    foundParent = True
                    if foundParent and '</parent>' in line:
                        foundParent = False
        return newLines

    def _process_slipstream_version(self, fileHandler):
        newLines = []
        for line in fileHandler:
            newLines.append(self._replaceIfFound(slipstream_version_re, line))
        return newLines

    def _replaceIfFound(self, pattern, line):
        res = pattern.findall(line)
        if res:
            version = res[0][1]
            newVersion = self._get_version_fn()(version)
            newLine = pattern.sub("\g<1>%s\g<3>" % newVersion, line)
        else:
            newLine = line
        return newLine

    def _get_version_fn(self):
        return (self.release and self._strip_snapshot) or self._add_snapshot_and_inc

    def _strip_snapshot(self, version):
        return version.split(snapshotPostfix)[0]

    def _add_snapshot_and_inc(self, version):
        striped = self._strip_snapshot(version)
        parts = striped.split('.')
        release = (int)(parts[-1])
        increased = parts[0:-1]
        newRelease = release + 1
        increased.append(str(newRelease))
        newVersion = '.'.join(increased)
        return newVersion + snapshotPostfix

    def _parse(self):
        parser = optparse.OptionParser(usage="usage: %prog [options] <pomfile>",
                                       option_class=Option)
        parser.add_option('--test', action='test',
                          help="run the test suite and exit")
        parser.add_option("-r", "--release",
                          dest="release",
                          action="store_true",
                          help="Release POM")
        parser.add_option("-s", "--snapshot",
                          dest="release",
                          action="store_false",
                          help="Set snapshot version POM")
        parser.add_option("-p", "--project",
                          dest="project",
                          action="store_true",
                          help="Change project version")
        parser.add_option("--slipstream",
                          dest="project",
                          action="store_false",
                          help="Change slipstream version")

        options, args = parser.parse_args()

        if len(args) < 1:
            print >> sys.stderr, "Missing <pomfile> argument"
            sys.exit(1)

        if options.release is None:
            print >> sys.stderr, "Missing -r/--release or -s/--snapshot"
            sys.exit(1)

        if options.project is None:
            sys.exit(1)
            print >> sys.stderr, "Missing -p/--project or --slipstream"

        self.pom = args[0]
        self.release = options.release
        self.project = options.project

    def run(self):
        self._parse()
        self.replace_version()


# TESTS #######################################################################

class TestPom(unittest.TestCase):

    def setUp(self):
        self.pom = Pom()

    def test_add_snapshot_and_inc(self):
        self.assertEqual(self.pom._add_snapshot_and_inc('2.1.9'), '2.1.10-SNAPSHOT')


def runtests():
    suite = unittest.TestLoader().loadTestsFromTestCase(TestPom)
    unittest.TextTestRunner().run(suite)


class Option(optparse.Option):

    ACTIONS = optparse.Option.ACTIONS + ("test",)

    def take_action(self, action, dest, opt, value, values, parser):
        if action == "test":
            runtests()
            parser.exit()
        else:
            optparse.Option.take_action(self, action, dest, opt, value, values,
                                        parser)


# MAIN ########################################################################

if __name__ == '__main__':
    Pom().run()
