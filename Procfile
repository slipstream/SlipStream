db: java -cp $HOME/.m2/repository/org/hsqldb/hsqldb/2.3.2/hsqldb-2.3.2.jar org.hsqldb.server.Server --database.0 file:slipstreamdb --dbname.0 slipstream
web: mvn jetty:run-war -f ${PWD}/../SlipStreamServer/war/pom.xml -Dpersistence.unit=hsqldb-schema -Dstatic.content.location=file://${PWD}/../SlipStreamUI/src/slipstream/ui/views
