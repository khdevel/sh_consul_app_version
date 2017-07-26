#!/bin/bash
#
# execution: main.sh -c dev.consul0.km.rst.com.pl -a testapp
#
# Kamil Herbik
#
set -e

readonly BASE64='/bin/base64'
readonly CURL='/bin/curl'
readonly GETOPTS='/bin/getopts'
readonly JQ='/bin/jq'
readonly TR='/bin/tr'
readonly YUM='/bin/yum'

# it may be localhost so it may be omited - need to be tested
CONSUL_ADDR=""
APPLICATION=""
VERSION=""

if ( ! getopts "a:c:h" opt); then
	echo "Usage: `basename $0` -a application_name -c consul_address";
	exit $E_OPTERROR;
fi

while getopts ":a:c:h" opt; do
  case $opt in
    a)
      APPLICATION=$OPTARG
      ;;
    c)
      CONSUL_ADDR=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ -z ${CONSUL_ADDR} ]; then
  echo "Lack of CONSUL_ADDR"
elif [ -z ${APPLICATION} ]; then
  echo "Lack of APPLICATION"
else
  VERSION=$(${CURL} -s http://${CONSUL_ADDR}:8500/v1/kv/${APPLICATION}/stable/version | ${JQ} '.[0].Value' | ${TR} -d '\"' | ${BASE64} --decode)
  ${YUM} install ${APPLICATION}-${VERSION}
  # VERSION=$(${CURL} -s http://${CONSUL_ADDR}:8500/v1/kv/${APPLICATION}/bind/frontend | ${JQ} '.[0].Value' | ${TR} -d '\"' | ${BASE64} --decode)
  # echo ${VERSION}
fi
