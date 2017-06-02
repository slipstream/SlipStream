(def +version+ "3.29")

(set-env!
  :project 'sixsq/default-deps
  :version +version+
  :license {"Apache 2.0" "http://www.apache.org/licenses/LICENSE-2.0.txt"}
  :edition "community"

  :resource-paths #{"src/main/resources"}

  :dependencies '[[org.clojure/clojure "1.9.0-alpha17"]
                  [sixsq/build-utils "0.1.4" :scope "test"]])

(require '[sixsq.build-fns :refer [merge-defaults
                                   sixsq-nexus-url
                                   lein-generate]])

(require '[clojure.java.io :as io]
         '[clojure.edn :as edn]
         '[clojure.walk :as walk])

(def all-deps (->> (io/resource "default-deps.edn")
                   slurp
                   edn/read-string
                   (walk/postwalk-replace {:version +version+})))

#_(clojure.pprint/pprint all-deps)

(set-env!
 :repositories
 #(reduce conj % [["sixsq" {:url (sixsq-nexus-url)}]])

 :dependencies all-deps)
     
(require '[boot-deps :refer [ancient]])
