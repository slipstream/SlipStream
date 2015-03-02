[![Stories in Ready](https://badge.waffle.io/SlipStream/SlipStream.png?label=ready&title=Ready)](https://waffle.io/SlipStream/SlipStream)
# SlipStream

Developed by SixSq, SlipStream is a multi-cloud coordinated
provisioning and image factory engine. In other words, it is an
engineering Platform as a Service (PaaS) solution to support
DevOps processes. Its AppStore feature makes deploying apps
in the cloud child's play.

See the [SlipStream product page][ss-product]
for more detailed information.

# Release Notes

Here are the [release notes](/release-notes.md).

# Getting started 

SlipStream is written in [Java], [Clojure], [Python] and [JavaScript].

It uses [Maven] to build the software and the standard xUnit
suites for unit testing.

This quick guide will help you setup a local development environment. For
more detailed information, check the links in the "Learn More" section below.

## Prerequisites

SlipStream has been tested and is working with the following versions:

* Java 1.7+
* Python 2.6+ (but not 3.0+)
* Maven 3
* pdflatex (for documentation generation)

The software should build without problems on any *nix-like
environment (Linux, FreeBSD, Mac OS X, etc.).  However, the packages
will only be built on platforms supporting RPM.


## Getting the source code

To build the entire system, you need the following GitHub repositories
into a common directory.

* [SlipStream](https://github.com/slipstream/SlipStream) 
* [SlipStreamDocumentation](https://github.com/slipstream/SlipStreamDocumentation)
* [SlipStreamDocumentationAPI](https://github.com/slipstream/SlipStreamDocumentationAPI)
* [SlipStreamUI](https://github.com/slipstream/SlipStreamUI)
* [SlipStreamServer](https://github.com/slipstream/SlipStreamServer)
* [SlipStreamServerDeps](https://github.com/slipstream/SlipStreamServerDeps)
* [SlipStreamClient](https://github.com/slipstream/SlipStreamClient)
* [SlipStreamConnectors](https://github.com/slipstream/SlipStreamConnectors)

Clone the SlipStream parent repository and execute the `git-pull.sh`
script:
```
$ git clone git@github.com:slipstream/SlipStream.git
$ SlipStream/git-pull.sh
```

**Note**: the above instructions will pull the master (bleeding edge). To be on the safe
side, you can change the script to pull a specific release tag.

**Note**: The given GitHub URLs require that you have a GitHub account with a 
registered SSH key.  If you do not, switch to using the HTTPS URLs for the
repositories.

## Installing dependencies

The primary platform used by the SlipStream developers is Mac OS X.  Production 
releases are compiled on CentOS 6.  The instructions should be easily ported to
any *nix-like system.  Windows is harder, but if you succeed, feel free to 
contribute the recipe :-)

### Mac OS X
We’re going to assume you're running OS X with [brew] and [easy_install] already installed.

```
$ brew install maven pandoc
$ sudo easy_install pip
$ sudo pip install nose coverage paramiko mock pylint
```

[brew]: http://brew.sh/
[easy_install]: http://python-distribute.org/distribute_setup.py

### CentOS 6

These instructions assume that you are building the software on an
**up-to-date, minimal CentOS 6 system**.  The build may work on other
distributions, but you may have to modify the packages or commands to
get a working version.

Several of the packages required for the build are not available in
the core CentOS 6 distribution.  You will need to configure your
machine to use the [EPEL 6 package repository][epel].

EPEL provides an RPM to do the configuration.  Just download the RPM
and install it with `yum`.

```
$ wget -nd <URL>
$ yum install -y <downloaded RPM>
```

You can find the URL and package name via the information in the "How
can I use these extra packages?" section on the [EPEL welcome
page][epel].

Most (but not all!) of the build dependencies can be installed
directly with `yum`.  The following table list the RPM packages that
must be installed and describes how those packages are used within the
build.

A command like:

```
$ yum install -y [packages]
```

will install all of the listed packages.

| Package                      | Comment                                  |
|:-----------------------------|:-----------------------------------------|
| java-1.7.0-openjdk-devel     | Compile and run the server               |
| python                       | Client CLI build and testing             |
| python-devel                 | Needed for python module dependencies    |
| pylint                       | Analysis of python code                  |
| python-pip                   | Installation of python modules           |
| python-mock                  | Mocking library used in unit tests       |
| gcc                          | c-bindings for python module dependencies|
| pandoc                       | Generates documentation from Markdown    |
| texlive-latex                | For PDF versions of docs                 |
| texlive-xetex                | For PDF versions of docs                 |
| git                          | Download sources from GitHub             |
| rpm-build                    | Creates binary distribution packages     |
| createrepo                   | Create local yum repository              |

There are a few python modules that must be installed with `pip`.  The
SlipStream code uses options and features that require more recent
versions than those packaged for CentOS 6.  The following table
provides details.  Use the command:

```
$ pip install nose coverage paramiko
```

to install all of these packages.

| Package    | Comment                             |
|:---------- |:------------------------------------|
| nose       | Unit testing utility for python code|
| coverage   | Coverage testing for python code    |
| paramiko   | SSH library for python              |

Lastly, the overall build is managed with Maven.  You will need to
download the [Maven distribution][mvn-download] (choose the most
recent binary distribution), unpack the distribution and modify the
environment to make the `mvn` command visible.

Once you have downloaded and unpacked Maven, you can setup the
environment with:

```
$ export MAVEN_HOME=<installation directory>/apache-maven-3.2.3
$ export PATH=$PATH:$MAVEN_HOME/bin
```

The `mvn` command should now be visible.  The software will build with
any maven version later than 2.2.1.

# Build everything

We use Maven to build everything.

```
$ cd SlipStream
$ touch .slipstream-build-all
$ mvn clean
$ mvn install
```

**Note**: if you get errors building the documentation, check that you have a working
installation of `pdflatex`.  If not, you can skip this by commenting out the
SlipStreamDocumentation module in the `pom.xml` file.

# Setup the database

SlipStream needs a JDBC friendly database. By default we use HSQLDB, but the persistence.xml file
contains a number of other databases, including MySQL and PostgreSQL. But feel free to add more.

Create an HSQLDB definition file:

```
$ cat > ~/sqltool.rc << EOF
urlid slipstream
url jdbc:hsqldb:hsql://localhost/slipstream
username SA
password
EOF
```

# Run SlipStream

## Run the database

```
$ java -cp ~/.m2/repository/org/hsqldb/hsqldb/2.3.2/hsqldb-2.3.2.jar org.hsqldb.server.Server \
       --database.0 file:slipstreamdb \
       --dbname.0 slipstream &
```

## Running the server

Run the server:

```
$ cd ../SlipStreamServer/war
$ mvn jetty:run-war
```

If the last command returns an error like `JettyRunWarMojo : Unsupported major.minor version 51.0` please have a look here: [Configuring Maven to use Java 7 on Mac OS X](http://www.jayway.com/2013/03/08/configuring-maven-to-use-java-7-on-mac-os-x/).

Now that the server’s running, visit
[http://localhost:8080/](http://localhost:8080/) with your Web browser.

As you can see, we run SlipStream as a war behind Jetty.

During development, especially when working on the UI with css and js files,
to avoid the war building round trip, you can start the server pointing to
source static location as following:

```
$ mvn jetty:run-war -Dstatic.content.location=file:../../SlipStreamUI/src/slipstream/ui/views 
```

You can also change the database backend connection using the `persistence.unit`. For
example:

```
-Dpersistence.unit=mysql-schema
```

or

```
-Dpersistence.unit=postgres-schema
```

# Configuring the server

## User(s)

During the initial startup of the server, an administrator account 
("super") will be created.  The initial password for this account is
"supeRsupeR".  You should log in as this user, visit the profile page
(single user icon at top), and change the password to another value.

You can also create new users accounts by visiting the "users" page 
(group of people icon at top).  

## Connector(s)

Once the server is up and running you need to configure a connector before
trying to deploy a module. Out of the box, using the local connector
is the easiest way to get started. To do so, navigate to the
[server configuration page](http://localhost:8080/configuration) and
define a cloud connector instance in the SlipStream Basics section:
```
test-cloud:local
```
You must be logged in with an administrator account to do this.  The 
value of this field has the form "name1:connector1,name2:connector2";
multiple instances of a single connector are permitted.  If the name
isn't given, it defaults to the connector name.

For configuration of other cloud connectors, check our [blog](http://sixsq.com/blog/index.html).

## Load default modules

The client module includes examples from the tutorial that can be loaded.
```
$ cd ../../SlipStreamClient/client/src/main/python
$ ./ss-module-upload.py --endpoint http://localhost:8080 -u test -p tesTtesT ../resources/doc/*
```
Change the username and password to an existing (preferably non-administrator)
account.

You now only need to configure the cloud parameters of a user (e.g. "test"). And
add the cloud IDs to the native images (e.g. Ubuntu, CentOS) you just created.

That's it!!

# Learn More

To learn more, we invite you to have a look at the [documentation][ss-docs].
We find particularly useful the [User Guide and Tutorial][ss-tutorial]
and [Administrator Manual][ss-admin].

You can also check [YouTube channel][ss-youtube] for tutorials, feature demonstrations and tips & tricks.

# License and copyright

Copyright (C) 2014 SixSq Sarl (sixsq.com)

The code in the public repositories is licensed under the Apache
license.

Licensed under the Apache License, Version 2.0 (the "License"); you
may not use this file except in compliance with the License.  You may
obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.  See the License for the specific language governing
permissions and limitations under the License.

[Java]: https://www.java.com
[Clojure]: http://clojure.org
[Python]: https://www.python.org
[JavaScript]: https://developer.mozilla.org/en-US/docs/Web/JavaScript
[Maven]: https://maven.apache.org/

[epel]: http://fedoraproject.org/wiki/EPEL
[mvn-download]: http://maven.apache.org/download.cgi

[ss-product]: http://sixsq.com/products/slipstream.html
[ss-docs]: https://slipstream.sixsq.com/documentation
[ss-tutorial]: https://slipstream.sixsq.com/html/tutorial.html
[ss-admin]: https://slipstream.sixsq.com/html/administrator-manual.html
[ss-youtube]: https://www.youtube.com/channel/UCGYw3n7c-QsDtsVH32By1-g
