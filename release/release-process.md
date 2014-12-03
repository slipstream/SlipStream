
Release Process
===============

This document describes the overall process for a release that is
captured in the Jenkins jobs.  This concentrates on the production of
the release artifacts and basically ignores things like verifying the
documentation, preparing release notes, etc.  (Those are important
too, but not described here!)

Jenkins Release Jobs
====================

There are 4 release-related jobs on the Jenkins server:
  * Community_Release
  * Enterprise_Release
  * Community_Release_Check
  * Enterprise_Release_Check
The names indicate which edition (Community or Enterprise) the job
deals with.

Check Jobs
==========

The jobs with "_Check" in their name verify that all the code can be
built and released.  These jobs run daily to ensure that the code is
always in a release-able state.

These jobs use the standard release process (as described below), but
run on bare copies of the production GitHub repositories and store
artifacts in an "internal" maven repository on disk.  This guarantees
that all of the release commits, tags, and artifacts are **completely
isolated from the production services**.

Release Jobs
============

The release jobs without "_Check" in their names must be triggered
manually and will perform a release using the **production GitHub
repositories** and the **production Nexus server**.

The procedure for each release is the following:
  1. The workspace for Jenkins is completely destroyed before the
  release procedure starts.
  2. The SlipStream repository is cloned into a subdirectory of the
  workspace. 
  3. All of the SlipStream repositories for the given edition are
  cloned into the workspace using the `git-pull.sh` script (or
  `release/git-pull-bare.sh` for the "_Check" jobs).
  4. The `.slipstream-build-all` file is created in the SlipStream
  repository to signal that all of the modules should be built
  together. 
  5. A "dry run" of the "release:prepare" goal is run within the
  SlipStream repository, creating the tag and next versions of the
  module `pom.xml` files.
  6. The tag `pom.xml` files are committed to the repositories and a
  tag is created.
  7. The next `pom.xml` files are committed to the repositories.
  8. The created tag is checked out in all of the local working copies
  of the repositories.
  9. A full build is started using `mvn clean deploy` in the
  SlipStream repository.
  10. As usual, all of the build artifacts are stored in the
  production Nexus server.


