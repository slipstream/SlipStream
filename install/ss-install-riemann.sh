#!/bin/bash

# Installs Riemann server on CentOS 7.
# Requires EPEL repository.

set -e
set -x

RIEMANN_VER=0.2.11-1
ss_clj_client=/opt/slipstream/downloads/clj-ss-client.jar
ss_riemann_conf=/etc/riemann/riemann-slipstream.config
ss_riemann_streams=/opt/slipstream/riemann

function srvc_start() {
    systemctl start $1
}
function srvc_enable() {
    systemctl enable $1
}
function _print() {
    echo -e "::: $@"
}

function _install_riemann() {
    yum localinstall -y https://aphyr.com/riemann/riemann-${RIEMANN_VER}.noarch.rpm
    srvc_enable riemann
}

function _add_ss_riemann_streams() {
    mkdir -p $ss_riemann_streams
    cat > $ss_riemann_conf<<EOF
; -*- mode: clojure; -*-
; vim: filetype=clojure

(logging/init {:file "/var/log/riemann/riemann.log"})

; Listen on the local interface over TCP (5555).
; Disable UDP (5555), and websockets (5556).
(let [host "127.0.0.1"]
  (tcp-server {:host host})
  #_(udp-server {:host host})
  #_(ws-server  {:host host}))

; Location of SlipStream Riemann streams.
(include "$ss_riemann_streams")
EOF
    cat >> /etc/sysconfig/riemann<<EOF
EXTRA_CLASSPATH=$ss_clj_client
RIEMANN_CONFIG=$ss_riemann_conf
EOF

    # Hack.  Our Clojure `superstring` requires different version of java/lang/String.
    #sed -i -e \
    #   's|JAR="/usr/lib/riemann/riemann.jar:$EXTRA_CLASSPATH"|JAR="$EXTRA_CLASSPATH:/usr/lib/riemann/riemann.jar"|' \
    #   /usr/bin/riemann
    #
    # NB! Damn... Riemann fails to start if we swap the classpath:
    #java -cp /opt/slipstream/downloads/clj-ss-client.jar:/usr/lib/riemann/riemann.jar riemann.bin start /etc/riemann/riemann.config
    #Exception in thread "main" java.lang.NoSuchMethodError: clojure.lang.Util.loadWithClass(Ljava/lang/String;Ljava/lang/Class;)Ljava/lang/Object;
    #        at riemann.bin.<clinit>(Unknown Source)
}

function deploy_riemann() {
  _print "Installing Riemann"
  _install_riemann
  _add_ss_riemann_streams
  srvc_start riemann
}

deploy_riemann
