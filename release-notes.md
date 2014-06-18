# Release Notes

## Development commits

[Server](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.2.5...master)  
[UI](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.2.5...master)  
[Client](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.2.5...master)  
[Documentation](https://github.com/slipstream/SlipStreamDocumentation/compare/SlipStreamDocumentation-2.2.5...master)  


## v2.2.5 - June 18th, 2014

### New features and bug fixes

- Some UI improvements related to the new state machine.
- In the UI when a Run page is loaded the delay of 10 seconds before the first update of the overview section was removed.
- Added the ability for privileged users to see the vmstate in the Runs of other users.
- Improved the migration of the garbage collector.
- Improved the logging and the error handling of describeInstance.
- Fixed an HTTP 500 when there is no user-agent in the request.
- Fixed a bug where when you try to build an image, run a deployment or run an image, the latest version is always used even if you were not on the latest version when creating the Run.


### Commits

[Server](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.2.4...SlipStreamServer-2.2.5)
[UI](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.2.4...SlipStreamUI-2.2.5)
[Client](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.2.4...SlipStreamClient-2.2.5)
[Documentation](https://github.com/slipstream/SlipStreamDocumentation/compare/SlipStreamDocumentation-2.2.4...SlipStreamDocumentation-2.2.5)


## v2.2.4 - June 13th, 2014

### Migration procedure

**IMPORTANT: v2.2.4 requires data migration from v2.2.3. The following steps MUST be followed:**
 1. Stop SlipStream
 2. Stop HSQLDB (or your DB engine)
 3. Execute the SQL files located in /opt/slipstream/server/migrations (file 006) 
 4. Start HSQLDB (or your DB engine)
 5. Start SlipStream**

Example command to execute the migration script:
```
java -jar /opt/hsqldb/lib/sqltool.jar --debug --autoCommit --inlineRc=url=jdbc:hsqldb:file:/opt/slipstream/SlipStreamDB/slipstreamdb,user=sa,password= /opt/slipstream/server/migrations/006_run_states_fix.sql
```

### New features and bug fixes

- New State Machine.
- New logic for the garbage collector.
- Auto-discovery of connectors.
- Fixed a bug where module parameters disappear of the old version when a new version is saved.
- Improved some RuntimeParameters.
- Fixed a bug where SSH login with keys doesn't work on images with SELinux enabled.
- Improved messages displayed during a Build.
- Added target script termination when abort flag is raised.
- Improved the detection of VMs not killed in a final state.

### Commits

[Server](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.2.3...SlipStreamServer-2.2.4)  
[UI](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.2.3...SlipStreamUI-2.2.4)  
[Client](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.2.3...SlipStreamClient-2.2.4)  
[Documentation](https://github.com/slipstream/SlipStreamDocumentation/compare/SlipStreamDocumentation-2.2.3...SlipStreamDocumentation-2.2.4)  


## v2.2.3 - June 2nd, 2014

### New features and bug fixes

- Improved error handling of CloudStack connector
- Fixed a bug with SSH (paramiko)
- Updated RPM packaging of SlipStream client
- Updated xFilesFactor of graphite.  For local update run the following 
```bash
for f in $(find /var/lib/carbon/whisper/slipstream/ -name *.wsp); do whisper-resize $f --xFilesFactor=0 --aggregationMethod=max 10s:6h 1m:7d 10m:5y; done
```

### Commits

[Server](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.2.2...SlipStreamServer-2.2.3)  
[UI](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.2.2...SlipStreamUI-2.2.3)  
[Client](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.2.2...SlipStreamClient-2.2.3)  
[Documentation](https://github.com/slipstream/SlipStreamDocumentation/compare/SlipStreamDocumentation-2.2.2...SlipStreamDocumentation-2.2.3)  



## v2.2.2 - May 27th, 2014

### New features and bug fixes

- Updated CloudStack connector to use the new TasksRunner when terminating instances
- Force draw on usage panel, since now default section

### Commits

[Server](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.2.1...SlipStreamServer-2.2.2)  
[UI](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.2.1...SlipStreamUI-2.2.2)  
[Client](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.2.1...SlipStreamClient-2.2.2)  
[Documentation](https://github.com/slipstream/SlipStreamDocumentation/compare/SlipStreamDocumentation-2.2.1...SlipStreamDocumentation-2.2.2)  


## v2.2.1 - May 26th, 2014

### Migration procedure

**IMPORTANT: v2.2.1 requires data migration from v2.2.0. The following steps MUST be followed:**
 1. Stop SlipStream
 2. Stop HSQLDB (or your DB engine)
 3. Execute the SQL files located in /opt/slipstream/server/migrations (file 005)
 4. Start HSQLDB (or your DB engine)
 5. Start SlipStream**

### New features and bug fixes

- Multi-thread bulk VM creation can be limited for clouds that can't cope
- Added support for CloudStack Advanced Zones as a sub-connector
- Fix issues related to API doc and xml processing
- Made c3p0 optional (see jar-persistence/src/main/resources/META-INF/persistence.xml for details)
- Add persistence support for MySQL and Postgres
- Update the OpenStack connector to use the new OpenStack CLI
- Update poms following SlipStreamParent -> SlipStream git repo rename
- Upgrade c3p0 version
- Now using Apache HTTP client connector unstead of default Restlet Client connector
- Streamline log entries for asynchronous activity
- Upgrade Restlet to v2.2.1
- Metering update communicate via temporary file instead of stdin
- Remove StratusLab from default configuration
- Fix strange orm issue with JPA 2.0
- A few more minor bug fixes

### Commits

[Server](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.2.0...SlipStreamServer-2.2.1)  
[UI](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.2.0...SlipStreamUI-2.2.1)  
[Client](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.2.0...SlipStreamClient-2.2.1)  
[Documentation](https://github.com/slipstream/SlipStreamDocumentation/compare/SlipStreamDocumentation-2.2.0...SlipStreamDocumentation-2.2.1)  


## v2.2.0 - May 10th, 2014

### Migration procedure

**IMPORTANT: v2.2.0 requires data migration from v2.1.x. The following steps MUST be followed:**
 1. Stop SlipStream
 2. Stop HSQLDB (or your DB engine)
 3. Execute the SQL files located in /opt/slipstream/server/migrations (files 001..004)
 4. Start HSQLDB (or your DB engine)
 5. Start SlipStream**

### New features and bug fixes

- Fixed performance issue under heavy load due to HashMap causing infinite loop
- Wrapping parameters of Parameterized into ConcurrentHashMap
- Improved asynchronious behaviour
- Improved metering feature
- Removed dependency on jclouds-slf4j
- Removed hibernate3 maven plugin
- Added SQL migration scripts
- Removed Nexus tasks for repo generation
- Migrate to Hibernate 4.3.5
- Fix checkbox not set correctly in edit mode for user
- Enable c3p0 database connection pooling by default
- Improve ergonomics of run dashboard
- Fixed issue with the metering legend items ending with a parenthesis
- Fix several minor bug

### Commits

[Server](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.1.16...SlipStreamServer-2.2.0)  
[UI](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.1.16...SlipStreamUI-2.2.0)  
[Client](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.1.16...SlipStreamClient-2.2.0)  
[Documentation](https://github.com/slipstream/SlipStreamDocumentation/compare/SlipStreamDocumentation-2.1.16...SlipStreamDocumentation-2.2.0)  
