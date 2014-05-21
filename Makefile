install:
	pip install -r requirements.txt
	touch .slipstream-build-all
	mvn clean install

cli_files = $(shell find ../SlipStreamClient/client/src/main/scripts -name 'cloudstack-*' -o -name 'openstack-*' | xargs grealpath)
link: $(cli_files)
	ln -sf $? /usr/bin/

run:
	foreman start
