# Release Notes

## Development

Server: [Commits](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.2.0...master)  
UI: [Commits](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.2.0...master)  
Client: [Commits](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.2.0...master)

## v2.2.0 - May 10th, 2014

IMPORTANT: v2.2.0 requires data migration from v2.1.x. The following steps MUST be followed:
1- Stop SlipStream
2- Stop HSQLDB (or your DB engine)
3- Execute the SQL files located in /opt/slipstream/server/migrations
4- Start HSQLDB (or your DB engine)
5- Start SlipStream

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

Server: [Commits](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.1.16...SlipStreamServer-2.2.0)  
UI: [Commits](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.1.16...SlipStreamUI-2.2.0)  
Client: [Commits](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.1.16...SlipStreamClient-2.2.0)

## v2.1.16 - May 3rd, 2014
...

Server: [Commits](https://github.com/slipstream/SlipStreamServer/compare/SlipStreamServer-2.1.15...SlipStreamServer-2.1.16)  
UI: [Commits](https://github.com/slipstream/SlipStreamUI/compare/SlipStreamUI-2.1.16...SlipStreamUI-2.1.15)  
Client: [Commits](https://github.com/slipstream/SlipStreamClient/compare/SlipStreamClient-2.1.16...SlipStreamClient-2.1.15)
