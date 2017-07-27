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
readonly RPM='/bin/rpm'
readonly TR='/bin/tr'
readonly YUM='/bin/yum'

# it may be localhost so it may be omited - need to be tested
CONSUL_ADDR=""
APPLICATION=""
VERSION=""

function parse_opts {
	local OPT=""

	if ( ! getopts "a:c:h" opt); then
		echo "Usage: `basename $0` -a application_name -c consul_address";
		exit ${E_OPTERROR};
	fi

	while getopts ":a:c:" OPT; do
	  case ${OPT} in
	    a)
	      APPLICATION="${OPTARG}"
	      ;;
	    c)
	      CONSUL_ADDR="${OPTARG}"
	      ;;
	    \?)
	      echo "Invalid option: -${OPTARG}" >&2
	      exit 1
	      ;;
	    :)
	      echo "Option -${OPTARG} requires an argument." >&2
	      exit 1
	      ;;
	  esac
	done

  if [ -z "${CONSUL_ADDR}" ]; then
		echo "You did not provide a Consul Address, use -c parameter" >&2
		exit 1
	elif [ -z "${APPLICATION}" ]; then
		echo "You did not provide an Application Name, use -a parameter" >&2
		exit 1
	fi

}

function check_key {
	local CONSUL_OUTPUT=""

	CONSUL_OUTPUT=$(${CURL} -s http://${CONSUL_ADDR}:8500/v1/kv/${APPLICATION}/stable/version)
  if [ -z "${CONSUL_OUTPUT}" ]; then
		echo "Your '-a APPLICAITON' is wrong, this key does not exist at Consul!" >&2
		exit 1
	fi
}

function get_version {

	VERSION=$(${CURL} -s http://${CONSUL_ADDR}:8500/v1/kv/${APPLICATION}/stable/version | ${JQ} '.[0].Value // empty' | ${TR} -d '\"' | ${BASE64} --decode)
  if [ -z "${VERSION}" ]; then
		echo "The key is empty, cannot determine version of the application!" >&2
		exit 1
	else
		printf "Application %s has version %s\n" "${APPLICATION}" "${VERSION}" >&2
	fi
}

function install_application {
  local INSTALL_CHECK=""

  printf "Checking wether an application %s is installed\n" "${APPLICATION}-${VERSION}" >&2
	INSTALL_CHECK=$(sudo "${RPM}" -qa "${APPLICATION}")

	if [ -z "${INSTALL_CHECK}" ]; then
		printf "Installing an application: %s\n" "${APPLICATION}-${VERSION}\n" >&2
	  sudo "${YUM}" install -y "${APPLICATION}"-"${VERSION}"
	else
		printf "Application %s installed, will do nothing!\n" "${APPLICATION}-${VERSION}" >&2
		exit 0
  fi

}

function main {
	parse_opts "${@}"
	check_key
	get_version
	install_application
	exit 0
}

main "$@"
