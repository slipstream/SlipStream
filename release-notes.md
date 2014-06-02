# Release Notes

## Development commits

[Server](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.2.2...master)  
[UI](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.2.2...master)  
[Client](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.2.2...master)  
[Documentation](https://github.com/slipstream/SlipStreamDocumentation/compare/SlipStreamDocumentation-2.2.2...master)  

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
