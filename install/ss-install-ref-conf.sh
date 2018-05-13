#!/bin/bash
set -ex
set -o pipefail

_SCRIPT_NAME=${0##*/}

_YUM_REPO_KIND_DEFAULT=snapshot
_YUM_REPO_EDITION_DEFAULT=community
_YUM_REPO_EDITIONS=(${_YUM_REPO_EDITION_DEFAULT} enterprise)

declare -A YUM_REPO_TO_GH_BRANCH
YUM_REPO_TO_GH_BRANCH[local]=master
YUM_REPO_TO_GH_BRANCH[${_YUM_REPO_KIND_DEFAULT}]=master
YUM_REPO_TO_GH_BRANCH[candidate]=candidate-latest
YUM_REPO_TO_GH_BRANCH[release]=release-latest

YUM_REPO_KIND=${_YUM_REPO_KIND_DEFAULT}
YUM_REPO_EDITION=${_YUM_REPO_EDITION_DEFAULT}

GH_BRANCH=

ES_HOST_PORT=localhost:9300

function usage_exit() {
    echo -e "usage:\n$_SCRIPT_NAME -a <ES host:port> -r <conf-url> -u <conf-url user:pass> -c <cert-url> -p <cert-url user:pass>
    -k <YUM repo kind> -e <YUM repo edition> -o '<parameters to slipstream.sh>'
-a Elasticsearch host:port. Default: $ES_HOST_PORT
-r reference configuration URL as https://host/path/file.tgz. Mandatory parameter.
-u credentials (user:pass) for URL with referece configuration. Optional parameter.
-c YUM certificate tarball url as https://host/path/file.tgz Optional parameter.
-p credentials (user:pass) for URL with YUM certificate tarball.  Optional parameter.
-k kind of the YUM repository to use: ${!YUM_REPO_TO_GH_BRANCH[@]}. Default: $_YUM_REPO_KIND_DEFAULT
-e edition of the YUM repository to use: ${_YUM_REPO_EDITIONS[@]}. Default: $_YUM_REPO_EDITION_DEFAULT
-o set of parameters to be passed to slipstream.sh installation script.
-b force the GitHub branch to download the install scripts from.
"
    exit 1
}

function _check_yum_repo_kind_to_github_tag_map() {
    if ! test "${YUM_REPO_TO_GH_BRANCH[$1]+isset}"; then
        usage_exit
    fi
}

function _check_repo_edition() {
    if [ "$1" != "community" ] && [ "$1" != "enterprise" ]; then
       usage_exit
    fi
}

while getopts a:r:u:c:p:k:e:o:b: opt; do
    case $opt in
    a)
        ES_HOST_PORT=$OPTARG
        ;;
    r)
        REFCONF_URL=$OPTARG
        ;;
    u)
        REFCONF_URL_USERPASS=$OPTARG
        ;;
    c)
        YUM_CREDS_URL=$OPTARG
        ;;
    p)
        YUM_CREDS_URL_USERPASS=$OPTARG
        ;;
    k)
        _check_yum_repo_kind_to_github_tag_map $OPTARG
        YUM_REPO_KIND=$OPTARG
        ;;
    e)
        _check_repo_edition $OPTARG
        YUM_REPO_EDITION=$OPTARG
        ;;
    o)
        SS_INSTALL_OPTIONS=$OPTARG
        ;;
    b)
        GH_BRANCH=$OPTARG
        ;;
    \?)
        usage_exit
        ;;
    esac
done

if [ -z "$REFCONF_URL" ]; then
    echo "ERROR: URL with reference configuration tarball was not provided."
    usage_exit
fi
if [ -z "$REFCONF_URL_USERPASS" ]; then
    echo "WARNING: Credentials for URL with reference configuration tarball were not provided."
fi
if [ -z "$YUM_CREDS_URL" ]; then
    echo "WARNING: URL with YUM certificates tarball was not provided."
fi
if [ -z "$YUM_CREDS_URL_USERPASS" ]; then
    echo "WARNING: Credentials for URL with YUM certificates tarball were not provided."
fi

if [ -n "$GH_BRANCH" ]; then
    branch=${GH_BRANCH}
else
    branch=${YUM_REPO_TO_GH_BRANCH[${YUM_REPO_KIND}]}
fi
GH_BASE_URL=https://raw.githubusercontent.com/slipstream/SlipStream/${branch}

SS_CONF_DIR=/etc/slipstream
mkdir -p $SS_CONF_DIR

function abort() {
    echo "!!! Aborting: $@"
    exit 1
}

function _now_sec() {
    date +%s
}

function _wait_listens() {
    # host port [timeout seconds] [sleep interval seconds]
    wait_time=${3:-60}
    sleep_interval=${4:-2}
    stop_time=$(($(_now_sec) + $wait_time))
    while (( "$(_now_sec)" <= $stop_time )); do
        set +e
        res=$(ncat -v -4 $1 $2 < /dev/null 2>&1)
        if [ "$?" == "0" ]; then
            set -e
            return 0
        else
            if ( ! (echo $res | grep -q "Connection refused") ); then
                abort "Failed to check $1:$2 with:" $res
            fi
        fi
        set -e
        sleep $sleep_interval
    done
    abort "Timed out after ${wait_time} sec waiting for $1:$2"
}

function _install_yum_client_cert() {
    [ -z "$YUM_CREDS_URL" ] && { echo "WARNING: Skipped intallation of YUM credentials."; return; }
    # Get and inflate YUM certs.
    TARBALL=~/yum-certs.tgz
    _CREDS=
    if [ -n "$YUM_CREDS_URL_USERPASS" ]; then
        _CREDS="-u $YUM_CREDS_URL_USERPASS"
    fi
    curl -k -L -sSf $_CREDS -o $TARBALL $YUM_CREDS_URL
    tar -C $SS_CONF_DIR -zxvf $TARBALL
    chmod 400 $SS_CONF_DIR/yum-client.*
    rm -f $TARBALL
}

function _install_reference_configuration() {
    # Get and inflate the tarball with the server configuration.
    TARBALL=~/ss-ref-conf.tgz
    _CREDS=
    if [ -n "$REFCONF_URL_USERPASS" ]; then
        _CREDS="-u $REFCONF_URL_USERPASS"
    fi
    curl -k -L -sSf $_CREDS -o $TARBALL $REFCONF_URL
    tar -C $SS_CONF_DIR -zxvf $TARBALL
    rm -f $TARBALL

    # Discover connectors that have to be installed.
    CONNECTORS_TO_INSTALL=$(awk '/:cloudConnectorClass/,/("|,)$/' $SS_CONF_DIR/slipstream.edn | \
        awk '
        {
            gsub(/.*:cloudConnectorClass[ \t]*/, "", $0)
            # input: "foo:bar, baz"
            # ouput: bar baz
            split($0, cnames, ",");
            for (i in cnames) {
                split(cnames[i], cn, ":")
                if (length(cn) == 2) {
                    cname = cn[2]
                } else {
                    cname = cn[1]
                }
                gsub(/[ \t"\n]/, "", cname)
                print " " cname
            };
        }' | sort -u)

    # Generate new passwords for the defined users.
    for passfile in /etc/slipstream/passwords/*; do
        echo -n $(uuidgen) | tail -c 12 > $passfile
    done

    # Ensure all files are owned by slipstream user
    chmod -R slipstream:slipstream $SS_CONF_DIR
}

function _install_slipstream() {
    # Install SlipStream, but don't start it.
    curl -sSf -k -o slipstream.sh $GH_BASE_URL/install/slipstream.sh
    chmod +x slipstream.sh
    ./slipstream.sh -S -k $YUM_REPO_KIND -e $YUM_REPO_EDITION \
        -a $ES_HOST_PORT $SS_INSTALL_OPTIONS
}

function _install_slipstream_connectors() {
    # Install required connectors.
    curl -sSf -k -o ss-install-connectors.sh \
        $GH_BASE_URL/install/ss-install-connectors.sh
    chmod +x ss-install-connectors.sh
    ./ss-install-connectors.sh -a $ES_HOST_PORT -r $YUM_REPO_KIND \
        $CONNECTORS_TO_INSTALL
}

function _start_slipstream() {
    # Start SlipStream.
    systemctl start cimi
    systemctl start slipstream
}

_install_yum_client_cert
_install_reference_configuration
_install_slipstream
_install_slipstream_connectors
_start_slipstream
