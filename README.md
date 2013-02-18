SlipStream
----------

SlipStream(TM) automates the deployment and testing of complete
software systems.


Overview
--------

The SlipStream service allows all members of a development team, from
programmers to operations personnel, to capture the complete
description of a software system, to deploy that system automatically,
and to run tests on the system, and to collect the results.

The automation of the deployment and testing of the full system:

  * Increases confidence in the released software,

  * Reduces the effort involved in deploying and maintaining the test
    infrastructure, 

  * Permits the full effects of changes in the system to be
    understood, and

  * Reduces time-to-market by freeing human resources to work on
    development rather than tedious manual deployment and testing.

SlipStream is a natural complement to existing unit testing
technologies.  It is designed to integrate well into any software
development process and can be adopted incrementally for smooth
transition from existing deployment and testing practices.


Building
--------

SlipStream(TM) is written in Java, JavaScript, XSLT and Python and
uses Maven2 for building the software. 

The system is tested using JUnit, Selenium and PyUnit.

To build the entire system, clone the following GitHub repositories:

  * [SlipStreamClient](https://github.com/SixSq/SlipStreamClient)
  * [SlipStreamDocumentation](https://github.com/SixSq/SlipStreamDocumentation)
  * [SlipStreamMta](https://github.com/SixSq/SlipStreamMta)
  * [SlipStreamParent](https://github.com/SixSq/SlipStreamClient) (this repository)
  * [SlipStreamServer](https://github.com/SixSq/SlipStreamServer)
  * [SlipStreamDeployment](https://github.com/SixSq/SlipStreamDeployment)

To build the full system, uncomment the modules element in the SlipStreamParent pom and run:
$ mvn clean install

You can also build each module individually, but you'll need to build the
[SlipStreamParent](https://github.com/SixSq/SlipStreamClient) (this repository) first.


Testing
-------

While unit tests are executed as part of the build process, end-to-end tests
are available in the [SlipStreamEndToEndTests](https://github.com/SixSq/SlipStreamEndToEndTests)
repository.

[SlipStreamEndToEndTests](https://github.com/SixSq/SlipStreamEndToEndTests) uses Selenium.
And by default it uses Firefox for the target browser.  You will therefore need to have
Firefox installed, and probably have the firefox-bin executable in your PATH.

To execute the end-to-end tests, execute the following in the 
[SlipStreamEndToEndTests](https://github.com/SixSq/SlipStreamEndToEndTests) directory:

    $ mvn clean install

This will launch the Selinium tests, implemented as standard JUnit tests, firing
Firefox in the process.
