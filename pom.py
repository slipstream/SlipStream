#!/usr/bin/env python

import sys
import re
from optparse import OptionParser

snapshotPostfix = '-SNAPSHOT'
project_version_re = re.compile('(<version>)(.*)(</version>)')
slipstream_version_re = re.compile('(<slipstream\.version>)([a-zA-Z0-9.-]+)(</slipstream\.version>)')


class Pom(object):

    def __init__(self):
        self.release = False
        self.project = False

    def replace_version(self):
        with open(self.pom, 'w') as fd:
            if self.project:
                newLines = self._process_project_version(fd)
            else:
                newLines = self._process_slipstream_version(fd)
                fd.writelines(newLines)

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
            newLine = pattern.sub("\g<1>%s\g<3>" % (newVersion), line)
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
        increased.extend(str(newRelease))
        newVersion = '.'.join(increased)
        return newVersion + snapshotPostfix

    def _parse(self):
        parser = OptionParser(usage="usage: %prog [options] <pomfile>")
        parser.add_option("-r", "--release",
                          dest="release",
                          action="store_true",
                          default=False,
                          help="Release POM")
        parser.add_option("-s", "--snapshot",
                          dest="snapshot",
                          action="store_true",
                          default=False,
                          help="Set snapshot version POM")
        parser.add_option("-p", "--project",
                          dest="project",
                          action="store_true",
                          default=False,
                          help="Change project version")
        parser.add_option("--slipstream",
                          dest="slipstream",
                          action="store_true",
                          default=False,
                          help="Change slipstream version")

        (options, args) = parser.parse_args()

        self.release = options.release
        snapshot = options.snapshot
        self.project = options.project
        slipstream = options.slipstream
        if(len(args) < 1):
            print >> sys.stderr, "Missing <pomfile> argument"
            sys.exit(1)

        self.pom = args[0]

        if not (self.release or snapshot):
            print >> sys.stderr, "Missing -r/--release or -s/--snapshot"
            sys.exit(1)

        if not (self.project or slipstream):
            print >> sys.stderr, "Missing -p/--project or --slipstream"
            sys.exit(1)

    def run(self):
        self._parse()
        self.replace_version()

if __name__ == '__main__':
    Pom().run()
