#!/bin/bash
# Install SlipStream NRPE monitoring

# Usage: <Nagios IP/hostname>

set -e
set -o pipefail
set -o errtrace

# Nagios remote plugin executor
NAGIOS_SERVER=${1:?"Provide Nagios server hostname/IP."}

NRPE_DEPS="nrpe nagios-plugins-procs nagios-plugins-load nagios-plugins-disk"
NRPE_D=/etc/nagios/nrpe.d
LIB_DIR=/usr/lib64

_NAGIOS_LIBEXEC=/usr/local/nagios/libexec
mkdir -p ${_NAGIOS_LIBEXEC}
CHECK_MEM_BIN=${_NAGIOS_LIBEXEC}/check_mem

LOG_FILE=/tmp/slipstream-nrpe-install.log
exec 4>&2 3>&1 1>>${LOG_FILE} 2>&1

function _print_on_trap() {
    _prints "\nERROR! Check log file ${LOG_FILE}\n... snippet ...\n$(tail -5 ${LOG_FILE})"
}

function _on_trap() {
    _print_on_trap
}

trap '_on_trap' ERR

function _prints() {
    echo -e "$@" 1>&3
}
function _print() {
    _prints "::: $@"
}
function _printn() {
    echo -en "::: $@" 1>&3
}

function _install_check_mem () {
    # check_mem
    # TODO: need to depend on a release version of check_mem.pl
    wget -O ${CHECK_MEM_BIN} \
        https://raw.github.com/justintime/nagios-plugins/master/check_mem/check_mem.pl
    chmod +x ${CHECK_MEM_BIN}
}

function _iptables_get_accept_rule () {
    PORT=$1
    ACCEPT_RULE="-A INPUT -m state --state NEW -m tcp -p tcp --dport $PORT -j ACCEPT"
    echo $ACCEPT_RULE
}

function add_nrpe_firewall_rules () {
    _printn " adding NRPE firewall rules... "
    NRPE_PORT=5666
    NRPE_RULE="$(_iptables_get_accept_rule $NRPE_PORT)"

    grep -q "dport $NRPE_PORT.*ACCEPT" /etc/sysconfig/iptables && \
        { _prints "(NRPE port already added) done."; return 0; } || true

    iptables-save > /etc/sysconfig/iptables
    sed -i.bak -e "/-A INPUT -j REJECT/i ${NRPE_RULE}" /etc/sysconfig/iptables
    service iptables restart || \
        { cp /etc/sysconfig/iptables.bak /etc/sysconfig/iptables; service iptables restart; }
    _prints "done."
}

function install_nrpe_monitoring () {
    _printn " installing NRPE... "
    for pkg in $NRPE_DEPS; do
        yum -y --enablerepo=epel install $pkg
    done
    _prints "done."

    _printn " configuring SlipStream NRPE checks... "
    sed -i -e 's|^allowed_hosts=.*$|allowed_hosts='${NAGIOS_SERVER}'|' /etc/nagios/nrpe.cfg
    sed -i -e 's|^debug=.*$|debug=1|' /etc/nagios/nrpe.cfg
    sed -i -e 's|^include_dir=.*$|include_dir='${NRPE_D}'|' /etc/nagios/nrpe.cfg

    _install_check_mem

    mkdir -p $NRPE_D
    cat > $NRPE_D/slipstream.cfg << EOF
command[check_hsqldb]=$LIB_DIR/nagios/plugins/check_procs -C java -a org.hsqldb.server.Server -c 1:1
command[check_rootpart]=$LIB_DIR/nagios/plugins/check_disk -w 20% -c 10% -p /
command[check_slipstream_backup]=/opt/slipstream/backup/nagios_check_slipstream_backup_timestamp
command[check_mem]=${CHECK_MEM_BIN} -w $ARG1$ -c $ARG2$ -f -C
EOF
    _prints "done."

    _printn " starting NRPE service... "
    # enable arguments to NRPE commands
    sed -i -e 's/^dont_blame_nrpe=.*/dont_blame_nrpe=1/' /etc/nagios/nrpe.cfg

    sed -i -e "s|# chkconfig:.*|# chkconfig: 36 60 45|" /etc/init.d/nrpe
    chkconfig --add nrpe

    service nrpe restart
    _prints "done."
}

_print "Installing SlipStream NRPE monitoring."
install_nrpe_monitoring
add_nrpe_firewall_rules
_print "SlipStream NRPE monitoring installed."

