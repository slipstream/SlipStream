#!/bin/bash
# Install SlipStream NRPE monitoring

# Usage: <Nagios IP/hostname>

set -ex

# Nagios remote plugin executor
NAGIOS_SERVER=${1:?"Provide Nagios server hostname/IP."}

NRPE_DEPS="nrpe nagios-plugins-procs nagios-plugins-load nagios-plugins-disk"
NRPE_D=/etc/nagios/nrpe.d
LIB_DIR=/usr/lib64

_NAGIOS_LIBEXEC=/usr/local/nagios/libexec
mkdir -p ${_NAGIOS_LIBEXEC}
CHECK_MEM_BIN=${_NAGIOS_LIBEXEC}/check_mem

function _install_check_mem () {
    # check_mem
    # TODO: need to depend on a release version of check_mem.pl
    wget -O ${CHECK_MEM_BIN} \
        https://raw.github.com/justintime/nagios-plugins/master/check_mem/check_mem.pl
    chmod +x ${CHECK_MEM_BIN}
}

function install_monitoring_nrpe () {

    echo "Installing NRPE..."
    yum -y --enablerepo=epel install $NRPE_DEPS

    sed -i -e 's|^allowed_hosts=.*$|allowed_hosts='${NAGIOS_SERVER}'|' /etc/nagios/nrpe.cfg
    sed -i -e 's|^debug=.*$|debug=1|' /etc/nagios/nrpe.cfg
    sed -i -e 's|^include_dir=.*$|include_dir='${NRPE_D}'|' /etc/nagios/nrpe.cfg

	_install_check_mem

    mkdir -p $NRPE_D
    cat > $NRPE_D/slipstream.cfg <<\EOF
command[check_hsqldb]=$LIB_DIR/nagios/plugins/check_procs -C java -a org.hsqldb.server.Server -c 1:1
command[check_rootpart]=$LIB_DIR/nagios/plugins/check_disk -w 20% -c 10% -p /
command[check_slipstream_backup]=/opt/slipstream/backup/nagios_slipstream_backup
command[check_mem]=${CHECK_MEM_BIN} -w $ARG1$ -c $ARG2$ -f -C
EOF

    # enable arguments to NRPE commands
    sed -i -e 's/^dont_blame_nrpe=.*/dont_blame_nrpe=1/' /etc/nagios/nrpe.cfg

    sed -i -e "s|# chkconfig:.*|# chkconfig: 36 60 45|" /etc/init.d/nrpe
    chkconfig --add nrpe

    service nrpe restart
}

install_monitoring_nrpe
