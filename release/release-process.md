
Release Process
===============

This document describes the overall process for a release that is
captured in the Jenkins jobs.

This concentrates on the production of the release artifacts and
basically ignores things like verifying the documentation, preparing
release notes, etc.  (Those are important too, but not described
here!)

Code Freeze
-----------

Releases happen systematically after the demo meeting for a sprint.
Nonetheless, remind everyone to push their accepted changes into the
master branch and to avoid any other changes in master until the
release has been finished.

Verification
------------

The Jenkins release job is optimized to perform the full release as
quickly as possible.  Consequently, it neight checks the consistency
of the Community and Enterprise code bases nor does it run the defined
unit tests.  **These checks must be done manually before triggering
the release build.**

### Code Base Consistency

To verify the consistency between the Community and Enterprise code
bases, check that all of the jobs named "Merge_*" (in the "SS Build"
tab) are passing.  Better manually trigger all of these jobs and
verify that they all pass.  (These jobs are extremely quick.)

If any of these jobs do not pass, then you'll have to manually resolve
any merge conflicts between the Community and Enterprise editions.
Consult the definition of the failing merge job to reproduce any merge
conflicts.

### Build Verification

The two jobs "Community_Build" and "Enterprise_Build" (also in the "SS
Build" tab) perform a full, consistent build of SlipStream.  Trigger
these builds manually **after** all of the changes for the release
have been pushed into the master branch.

Disable Build Jobs
------------------

The individual build jobs in the "SS Community" and "SS Enterprise"
tabs are triggered on changes in the repository.  As the release
process proceeds, they will be triggered, slowing down the overall
release process.  

To make the release as quickly as possible, disable all of the build
jobs on these two tabs. 

Trigger Release
---------------

The "SlipStream_release_check_full" partially checks the release build
process.  You can trigger this job to do further tests of the release
process, without actually checking any changes into the GitHub
repositories. 

The "SlipStream_release_full" job in the "SS Release" tab will perform
the **complete release of SlipStream** (both the Community and
Enterprise editions).  If all goes well, the full release should be
built in around 15 minutes.

If things do not go well, then you'll need to troll through the logs
to determine what failed.  You'll then have to manually clean up any
tags that were made in the repositories, fix any issues, and try the
release again. 

Publishing Releases
-------------------

All of the candidate releases are published automatically into the YUM
repository automatically via a cron job on the yum server
(`yum.sixsq.com`).  Nonetheless, you should verify that the new
release does appear after the build.

**Stable releases are published manually.**  If the previous candidate
release was judged to be stable, then you can publish it by doing the
following: 

  1. Log into `yum.sixsq.com` as root.
  2. Run the script `./bin/publish-release.sh RELEASE_NUMBER` 

This will then scan the Nexus repository and publish the release with
the given RELEASE_NUMBER.  Verify that the release does indeed show up
in the YUM repository. 

Enable Build Jobs
-----------------

If you disabled the build jobs on the "SS Community" and "SS
Enterprise" tabs, then you should re-enable them after the release has
been completed.

You should also manually trigger the full build from the root build
job for each of these.  There may be intermediate failures in these
jobs if they are performed out of the usual build order because the
correct snapshot version of a dependency may not exist yet.

You should also manually trigger the full builds on the "SS Build"
tab.  Verify that these pass with the new snapshot version. 


Updating Release Notes
----------------------

The release notes are created as part of the standard SlipStream
documentation on http://ssdocs.sixsq.com.  To update these release
notes, clone the SlipStreamDocumentation repository and add the
release notes to the **candidate category**.

If the previous candidate release was promoted to stable, then you
must also copy the release notes into the stable releases page,
combining multiple candidate release entries if there has been a gap. 

Follow the instructions in that repository's README to publish the new
release notes.  Verify that the new release notes have indeed been
published. 


Publishing SlipStream Client
----------------------------

If you've published a new stable release, then you should also publish
the associated SlipStream client to PyPi.  

Before starting, get the PyPi credentials from the `slipstream.txt`
file and create your `~/.pypirc` file.

The publishing procedure is then:

  1. Clone the SlipStreamClient repository
  2. Checkout the stable release tag
  3. Descend into the `pypi` subdirectory
  4. Run `mvn clean install -P release`
  5. Descend into `target/pypi-pkg`
  6. Run `python setup.py sdist`
  7. Publish it with `python setup.py sdisk upload`

Then verify on PyPi that the new version is available.

