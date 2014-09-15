# SlipStream

Developed by SixSq, SlipStream is a multi-cloud coordinated
provisioning and image factory engine. In other words, it is an
engineering Platform as a Service (PaaS) solution to support
DevOps processes. It's AppStore feature makes deploying app
in the cloud a child's play.

See the [SlipStream product page]( http://sixsq.com/products/slipstream.html)
for more detailed information.


# Release Notes

Here are the [release notes](/release-notes.md).

# Getting started 

SlipStream is written in [Java], [Clojure], [Python] and [JavaScript].

It uses [Maven] to build the software and the standard xUnit
suites for unit testing.

[Java]: https://www.java.com
[Clojure]: http://clojure.org
[Python]: https://www.python.org
[JavaScript]: https://developer.mozilla.org/en-US/docs/Web/JavaScript
[Maven]: https://maven.apache.org/

This quick guide will help you setup a local development environment. For
more indepth knowledge, including how to deploy a production environment,
we invite you to have a look at the
[documentation](https://slipstream.sixsq.com/documentation).
We find particularly useful the [User Guide and Tutorial](https://slipstream.sixsq.com/html/tutorial.html)
and [Administrator Manual](https://slipstream.sixsq.com/html/administrator-manual.html).

You can also check our up-coming [YouTube channel](https://www.youtube.com/channel/UCGYw3n7c-QsDtsVH32By1-g
) for tutorials, feature demonstrations and tip & tricks.

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

First, clone the SlipStream parent repository and execute the git-pull.sh
script:
```
$ git clone git@github.com:slipstream/SlipStream.git
$ SlipStream/git-pull.sh
```

Note: the above instructions will pull the master (bleeding edge). To be on the safe
side, you can change the script to pull a specific release tag.

## Installing dependencies

We’re going to assume you're running OS X with [brew] and [easy_install] already installed, otherwise you can probably find equivalent packages on other *nix OSs. Windows is harder, but if you succeed, feel free to contribute the recipe :-)

```
$ brew install maven pandoc
$ sudo easy_install pip
$ sudo pip install nose coverage paramiko mock pylint
$ export LC_CTYPE="en_US.UTF-8"
```

[brew]: http://brew.sh/
[easy_install]: http://python-distribute.org/distribute_setup.py

# Build everything

We use Maven to build everything.

```
$ cd SlipStream
$ touch .slipstream-build-all
$ mvn clean
$ mvn install
```

Note: if you get errors building the documentation, check that you have a working
installation of pdflatex.  If not, you can skip this by commenting out the SlipStreamDocumentation
module in the pom.xml

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
$ java -cp ~/.m2/repository/org/hsqldb/hsqldb/2.3.2/hsqldb-2.3.2.jar org.hsqldb.server.Server --database.0 file:slipstreamdb --dbname.0 slipstream &
```

## Running the server

Run the server:

```
$ cd ../SlipStreamServer/war
$ mvn jetty:run-war
```

If the last command return an error like `JettyRunWarMojo : Unsupported major.minor version 51.0` please have a look here: [Configuring Maven to use Java 7 on Mac OS X](http://www.jayway.com/2013/03/08/configuring-maven-to-use-java-7-on-mac-os-x/).

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

## Connector(s)

Once the server is up and running you need to configure a connector before
trying to deploy a module. Out of the box, using the local connector
is the easiest way to get started. To do so, navigate to the
[server configuration page](http://localhost:8080/configuration) and
define a cloud connector instance in the SlipStream Basics section:

```
dummy:com.sixsq.slipstream.connector.local.LocalConnector
```

For other cloud connector configuration, check our [blog](http://sixsq.com/blog/index.html).

## Load default modules

The client module includes examples that can be loaded.

```
$ cd ../../SlipStreamClient/client/src/main/python
$ ./ss-module-upload.py --endpoint http://localhost:8080 -u test -p tesTtesT ../resources/doc/*
```

Here we are using the default password of the test account. It's a good idea to change
these!

You now only need to configure the cloud parameters of a user, say test. And
add the cloud ids to the native images (e.g. Ubuntu, CentOS) you just create.

That's it!!

To learn more, we invite you to have a look at the
[documentation](https://slipstream.sixsq.com/documentation).
We find particularly useful the [User Guide and Tutorial](https://slipstream.sixsq.com/html/tutorial.html)
and [Administrator Manual](https://slipstream.sixsq.com/html/administrator-manual.html).

You can also check our up-coming [YouTube channel](https://www.youtube.com/channel/UCGYw3n7c-QsDtsVH32By1-g
) for tutorials, feature demonstrations and tip & tricks.


# License

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
