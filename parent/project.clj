(def +version+ "3.42-SNAPSHOT")

(defproject sixsq.slipstream/parent "3.42-SNAPSHOT"
  :description "parent project file for SlipStream modules"
  :url "https://github.com/slipstream"
  :license {:name "Apache 2.0"
            :url  "http://www.apache.org/licenses/LICENSE-2.0"}

  :plugins [[lein-ancient "0.6.14"]]

  ;:dependencies [[org.clojure/clojure "1.9.0"]]

  :filespecs [{:type :path
               :path "./project.clj"}]

  :managed-dependencies
  [
   ;;
   ;; core languages
   ;;

   [org.clojure/clojure "1.9.0"]
   [org.clojure/clojurescript "1.9.946"]

   ;;
   ;; slipstream dependencies
   ;;

   [com.sixsq.slipstream/auth ~+version+]
   [com.sixsq.slipstream/token ~+version+]
   [com.sixsq.slipstream/utils ~+version+]
   [com.sixsq.slipstream/Libcloud-SixSq-zip ~+version+]
   [com.sixsq.slipstream/SlipStreamAsync ~+version+]
   [com.sixsq.slipstream/SlipStreamClientAPI-jar ~+version+]
   [com.sixsq.slipstream/SlipStreamDbBinding-jar ~+version+]
   [com.sixsq.slipstream/SlipStreamDbSerializers-jar ~+version+]
   [com.sixsq.slipstream/SlipStreamCljResources-jar ~+version+]
   [com.sixsq.slipstream/SlipStreamCljResourcesTests-jar ~+version+]
   [com.sixsq.slipstream/SlipStreamCljResourcesTestServer-jar ~+version+ :scope "test"]
   [com.sixsq.slipstream/SlipStreamConnector ~+version+ :scope "test"]
   [com.sixsq.slipstream/SlipStreamCredCache ~+version+]
   [com.sixsq.slipstream/SlipStreamPersistence ~+version+ :scope "test"]
   [com.sixsq.slipstream/SlipStreamServer-jar ~+version+ :scope "test"]
   [com.sixsq.slipstream/SlipStreamServer-ui-static-content ~+version+ :type "zip"]
   [com.sixsq.slipstream/SlipStreamService ~+version+ :scope "test"]
   [com.sixsq.slipstream/SlipStreamUI ~+version+]
   [com.sixsq.slipstream/SlipStreamPricingLib-jar ~+version+]
   [com.sixsq.slipstream/SlipStreamPlacementLib-jar ~+version+]
   [com.sixsq.slipstream/SlipStreamConnector-Azure-conf ~+version+]
   [com.sixsq.slipstream/SlipStreamConnector-CloudStack-conf ~+version+]
   [com.sixsq.slipstream/SlipStreamConnector-EC2-conf ~+version+]
   [com.sixsq.slipstream/SlipStreamConnector-Exoscale-conf ~+version+]
   [com.sixsq.slipstream/SlipStreamConnector-NativeSoftLayer-conf ~+version+]
   [com.sixsq.slipstream/SlipStreamConnector-NuvlaBox-conf ~+version+]
   [com.sixsq.slipstream/SlipStreamConnector-OpenNebula-conf ~+version+]
   [com.sixsq.slipstream/SlipStreamConnector-OpenStack-conf ~+version+]
   [com.sixsq.slipstream/SlipStreamConnector-OTC-conf ~+version+]
   [com.sixsq.slipstream/SlipStreamConnector-StratusLab-conf ~+version+]
   [com.sixsq.slipstream/slipstream-ring-container ~+version+]
   [com.sixsq.slipstream/cimi-resources-jar ~+version+]
   [com.sixsq.slipstream/cimi-resources-tests-jar ~+version+]

   ;;
   ;; general dependencies
   ;; (please keep these in alphabetical order)
   ;;

   [aleph "0.4.4"]

   [binaryage/devtools "0.9.8"]
   [buddy/buddy-core "1.4.0"]
   [buddy/buddy-hashers "1.3.0"]
   [buddy/buddy-sign "2.2.0"]

   [camel-snake-kebab "0.4.0"]
   [cc.qbits/spandex "0.5.4"]
   [cheshire "5.8.0"]                                       ;; newer, explicit version needed by ring-json
   [clj-http "3.7.0"]
   [clj-stacktrace "0.2.8"]
   [clj-time "0.14.2"]
   [clojure-ini "0.0.2"]
   [commons-logging "1.2"]
   [commons-lang/commons-lang "2.6"]
   [commons-codec/commons-codec "1.11"]
   [compojure "1.6.0"]
   [com.andrewmcveigh/cljs-time "0.5.2"]
   [com.cemerick/url "0.1.1"]
   [com.jcraft/jsch "0.1.54"]
   [com.taoensso/tempura "1.1.2"]
   [com.taoensso/tower "3.1.0-beta5"]

   ;; Pinned to this version because of a dependency conflict with the
   ;; deprecated tower library used by SlipStreamUI.
   [com.taoensso/timbre "4.7.4"]

   ;; cljs testing; control options here
   [doo "0.1.8" :scope "test"]

   [enlive "1.1.6"]
   [environ "1.1.0"]
   [expound "0.3.4"]

   [honeysql "0.6.2"]
   [http-kit "2.2.0"]

   [instaparse "1.4.8"]
   [io.nervous/kvlt "0.1.5-SNAPSHOT"
    :exclusions [org.clojure/clojurescript]]

   [javax.mail/mail "1.4.7" :scope "compile"]
   [javax.servlet/javax.servlet-api "3.1.0"]

   [korma "0.4.2"]

   [log4j "1.2.17"
    :exclusions [javax.mail/mail
                 javax.jms/jms
                 com.sun.jdmk/jmxtools
                 com.sun.jmx/jmxri]]
   [org.apache.logging.log4j/log4j-core "2.9.1"]
   [org.apache.logging.log4j/log4j-api "2.9.1"]
   [org.apache.logging.log4j/log4j-web "2.9.1"]
   [org.slf4j/slf4j-simple "1.7.25"]

   [me.raynes/fs "1.4.6"]
   [metrics-clojure "2.10.0"]
   [metrics-clojure-ring "2.10.0"]
   [metrics-clojure-jvm "2.10.0"]
   [metrics-clojure-graphite "2.10.0"]

   [net.cgrand/moustache "1.1.0"]

   [org.clojure/data.xml "0.0.8"]
   [org.clojure/data.zip "0.1.2"]
   [org.clojure/tools.cli "0.3.5"]
   [org.clojure/tools.logging "0.4.0"]
   [org.clojure/tools.namespace "0.2.11"]
   [org.clojure/data.json "0.2.6"]
   [org.clojure/java.classpath "0.2.3"]
   [org.clojure/java.jdbc "0.4.2"]
   [org.clojure/core.async "0.3.465" :exclusions [org.clojure/tools.reader]]
   [org.clojure/test.check "0.9.0" :scope "test"]
   [org.elasticsearch/elasticsearch "5.5.0"]
   [org.elasticsearch.client/transport "5.5.0"]
   [org.elasticsearch.plugin/transport-netty4-client "5.5.0"]
   [org.elasticsearch.test/framework "5.5.0"
    :exclusions [com.carrotsearch.randomizedtesting/randomizedtesting-runner]]

   [org.hsqldb/hsqldb "2.3.4"]
   [org.json/json "20171018"]
   [org.slf4j/slf4j-api "1.7.25"]
   [org.slf4j/slf4j-jdk14 "1.7.25"]
   [org.slf4j/slf4j-log4j12 "1.7.25"]
   [org.apache.curator/curator-test "2.8.0" :scope "test"]

   [potemkin "0.4.4"]

   [reagent "0.7.0"]
   [re-com "2.1.0"]
   [re-frame "0.10.2"]
   [ring "1.6.3"]
   [ring/ring-core "1.6.3"]
   [ring/ring-codec "1.1.0"]
   [ring/ring-json "0.4.0"]
   [ring/ring-defaults "0.3.1"]

   [secretary "1.2.3"]
   [superstring "2.1.0"]

   [zookeeper-clj "0.9.4"]
   [org.apache.zookeeper/zookeeper "3.4.11"
    :exclusions [jline
                 org.slf4j/slf4j-log4j12]]

   ;;
   ;; libraries and utilities for testing
   ;;
   [junit "4.12" :scope "test"]
   [org.clojure/tools.nrepl "0.2.13" :scope "test"
    :exclusions [org.clojure/clojure]]
   [clojure-complete/clojure-complete "0.2.4" :scope "test"
    :exclusions [org.clojure/clojure]]
   [peridot "0.5.0" :scope "test"]
   [expectations "2.1.9" :scope "test"]
   ]

  :repositories [["third-party" {:url           "http://nexus.sixsq.com/content/repositories/thirdparty/"
                                 :snapshots     false
                                 :sign-releases false
                                 :checksum      :fail
                                 :update        :daily}]
                 ["community-snapshots" {:url           "http://nexus.sixsq.com/content/repositories/snapshots-community-rhel7/"
                                         :snapshots     true
                                         :sign-releases false
                                         :checksum      :fail
                                         :update        :always}]
                 ["community-releases" {:url           "http://nexus.sixsq.com/content/repositories/releases-community-rhel7/"
                                        :snapshots     false
                                        :sign-releases false
                                        :checksum      :fail
                                        :update        :daily}]
                 ["enterprise-snapshots" {:url           "http://nexus.sixsq.com/content/repositories/snapshots-enterprise-rhel7/"
                                          :snapshots     true
                                          :sign-releases false
                                          :checksum      :fail
                                          :update        :always}]
                 ["enterprise-releases" {:url           "http://nexus.sixsq.com/content/repositories/releases-enterprise-rhel7/"
                                         :snapshots     false
                                         :sign-releases false
                                         :checksum      :fail
                                         :update        :daily}]])
