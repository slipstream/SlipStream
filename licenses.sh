#!/bin/bash

# To use this script:
# 1. Go to parent directory with all SlipStream modules: cd ../
# 2. Run script: ./SlipStream/licenses.sh > licenses.log 2>&1
# 3. All license information in licenses-all.tar.gz
# 4. Enjoy!

## Clean all license files.
(cd SlipStream; mvn clean -P enterprise-build)

## Generates dependencies.html for all Java modules

(cd SlipStream; mvn -P enterprise-build project-info-reports:dependencies)

## Clojure(Script) dependencies

rm -f dirs.txt
for i in `find . -name project.clj | grep -v module/ `; do (echo `dirname $i` >> dirs.txt); done
for i in `cat dirs.txt`; do (cd $i; echo $i; mkdir -p target; lein licenses > target/licenses-clj.txt); done
rm -f dirs.txt

## Node.js dependencies from WebUI

(cd SlipStreamWebUI; mkdir -p target; npm install; ./node_modules/.bin/license-checker > target/licenses-npm.txt)

## Python dependencies

rm -f dirs.txt
for i in `find . -name requirements.txt`; do (echo `dirname $i` >> dirs.txt); done
for i in `cat dirs.txt`; do (\
                             cd $i; \
                             echo $i; \
                             mkdir -p target ; \
                             virtualenv target/deps-env; \
                             source target/deps-env/bin/activate; \
                             pip install -r requirements.txt; \
                             pip install pip-licenses; \
                             pip-licenses > target/licenses-pypi.txt); \
done;

rm -f dirs.txt

## Bundle all license information

find . -path '*/site/*' -o -name licenses-\*.txt | tar zcf licenses-all.tar.gz -T -
