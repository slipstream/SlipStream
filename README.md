# SlipStream

Developed by SixSq, SlipStream is a multi-cloud coordinated
provisioning and image factory engine. In other words, it is an
engineering Platform as a Service (PaaS) solution to support
production deployment in the cloud, as well as development, testing,
certification and deployment processes into Infrastructure as a
Service (IaaS) cloud environments.

See the [SlipStream product page][slipstream-info] for more detailed
information.

# Release Notes

Here are the [release notes](/release-notes.md).

# Building

SlipStream is written in Java, Clojure, Python and JavaScript.
It uses Maven to build the software and the standard xUnit
suites for unit testing.

## Prerequisites

You must have Java 1.7+ and Python 2.6+ (but not 3.0+) installed on
your system.  You must also have Maven 3 installed. 

The software should build without problems on any *nix-like
environment (Linux, FreeBSD, Mac OS X, etc.).  However, the packages
will only be built on platforms supporting RPM.

## Checkout

To build the entire system, clone the following GitHub repositories
into a common directory:

  * [SlipStream](https://github.com/slipstream/SlipStream)
  * [SlipStreamDocumentation](https://github.com/slipstream/SlipStreamDocumentation)
  * [SlipStreamMta](https://github.com/slipstream/SlipStreamMta)
  * [SlipStreamUI](https://github.com/slipstream/SlipStreamUI)
  * [SlipStreamServer](https://github.com/slipstream/SlipStreamServer)
  * [SlipStreamServerDeps](https://github.com/slipstream/SlipStreamServerDeps)
  * [SlipStreamClient](https://github.com/slipstream/SlipStreamClient)

## Running Maven

To build the full system, descend into the SlipStreamParent
subdirectory and create the file `.slipstream-build-all`.  Then run:

```
$ mvn clean install
```

You can also build each module individually, but you'll need to build
them in the order in the above list.  Execute the same Maven command
at the root of each cloned repository.

# Testing

Unit tests are executed as part of the build process, for both the
client and the server.  Failures will cause the build process to
abort. 

# Running

To run the SlipStream server directly from the local git repositories,
you can drop into the `SlipStreamServer/war` module and run:

```
mvn jetty:run-war
```

The server will show up on the [local machine](http://localhost:8080). 

By default, SlipStream runs with a in memory hsqldb instance. While this is
great for unit testing, it's not ideal for end-to-end testing or simple deployment.

To attach to an existing hsqldb instance, the following java options can be used:

```
mvn jetty:run-war -Dpersistence.unit=hsqldb-schema
```

To start a separate hsqldb, run the following:

```
$ java -cp ~/.m2/repository/org/hsqldb/hsqldb/2.3.2/hsqldb-2.3.2.jar org.hsqldb.server.Server --database.0 file:slipstreamdb --dbname.0 slipstream &
```

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


[slipstream-info]: http://sixsq.com/products/slipstream.html
