SRC_DIR = $(shell grealpath ../SlipStreamClient/client/src)

install:
	pip install -r requirements.txt
	touch .slipstream-build-all
	mvn clean install

cli_files = $(shell find $(SRC_DIR)/main/scripts -name 'cloudstack-*' -o -name 'openstack-*')
link-cli: $(cli_files)
	sudo ln -sf $? /usr/bin/

pythonpath = $(shell python -c 'from distutils.sysconfig import get_python_lib; print get_python_lib()')
link-path:
	ln -sf $(SRC_DIR)/main/python/slipstream $(pythonpath)
	ln -sf $(SRC_DIR)/external/* $(pythonpath)

link: link-cli link-path

run:
	foreman start
