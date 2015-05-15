#!/bin/bash

destination="target/yum"
mkdir -p ${destination}
find ../../ -name \*.rpm -exec cp {} ${destination} \; 

createrepo ${destination}

