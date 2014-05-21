# SlipStream

Developed by SixSq, SlipStream is a multi-cloud coordinated
provisioning and image factory engine. In other words, it is an
engineering Platform as a Service (PaaS) solution to support
production deployment in the cloud, as well as development, testing,
certification and deployment processes into Infrastructure as a
Service (IaaS) cloud environments.

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


## Prerequisites

SlipStream has been tested and is working with the following versions:

* Java 1.7+
* Python 2.6+ (but not 3.0+)
* Maven 3

The software should build without problems on any *nix-like
environment (Linux, FreeBSD, Mac OS X, etc.).  However, the packages
will only be built on platforms supporting RPM.


## Getting the source code

To build the entire system, clone the following GitHub repositories
into a common directory:

* [SlipStream](https://github.com/slipstream/SlipStream) 
* [SlipStreamDocumentation](https://github.com/slipstream/SlipStreamDocumentation)
* [SlipStreamMta](https://github.com/slipstream/SlipStreamMta)
* [SlipStreamUI](https://github.com/slipstream/SlipStreamUI)
* [SlipStreamServer](https://github.com/slipstream/SlipStreamServer)
* [SlipStreamServerDeps](https://github.com/slipstream/SlipStreamServerDeps)
* [SlipStreamClient](https://github.com/slipstream/SlipStreamClient)

```
$ for project in SlipStream SlipStreamDocumentation SlipStreamMta SlipStreamUI SlipStreamServer SlipStreamServerDeps SlipStreamClient; do git clone https://github.com/slipstream/$project; done
```


## Installing dependencies

We’re going to assume you're running OS X with [brew] already installed, otherwise you’re on your own.

```
$ brew install cmake coreutils python maven
```

Install [foreman](https://ddollar.github.io/foreman/) (to run database and webserver processes):

```
$ gem install foreman
```

And finally let’s make sure we have [virtualenv](http://virtualenv.readthedocs.org)
for our Python environment:

```
$ pip install --upgrade virtualenv
```

[brew]: http://brew.sh/


## Configure the environment

Create a Python environment:

```
# set cwd to repo root
$ cd /path/to/SlipStream

# create a base environment
$ virtualenv .venv

# "activate" the environment, so python becomes localized
$ source .venv/bin/activate
```

Bootstrap your environment:

```
# install basic dependencies
$ make install

# link client scripts
$ make link
```


## Running the webserver

Run the webserver and a persisted database:

```
$ make run
```

Now that the server’s running, visit
[http://127.0.0.1:8000/](http://127.0.0.1:8000/) with your Web browser.

The websever is configuraed so that any changes made into the SlipStreamUI
assets (css, js) are reflected without reloading the process.

Please note that the server process needs to build a WAR ran by
Jetty behind the scenes, which can take some time.

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
