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
APPLICATION=""
CONSUL_ADDR=""
TEST=false

function _get_version {
	local VERSION=""

	VERSION=$(${CURL} -s http://${CONSUL_ADDR}:8500/v1/kv/services/${APPLICATION}/versions/stable | ${JQ} '.[0].Value // empty' | ${TR} -d '\"' | ${BASE64} --decode)
  if [ -z "${VERSION}" ]; then
		echo "The key is empty, cannot determine version of the application!" >&2
		exit 1
	else
		echo "${VERSION}"
	fi
}

function _get_application_env {
	local APPLICATION_ENV=""
	local VERSION=""

	VERSION=$(_get_version)

	APPLICATION_ENV=$(${CURL} -s http://${CONSUL_ADDR}:8500/v1/kv/services/${APPLICATION}/configs/${VERSION}/APPLICATION_ENV | ${JQ} '.[0].Value // empty' | ${TR} -d '\"' | ${BASE64} --decode)
  if [ -z "${APPLICATION_ENV}" ]; then
		echo "The key is empty, cannot determine APPLICATION_ENV of the ${APPLICATION}-${VERSION}!" >&2
		exit 1
	else
		echo "${APPLICATION_ENV}"
	fi
}

function _get_exec_user {
	local EXEC_USER=""
	local VERSION=""

	VERSION=$(_get_version)

	EXEC_USER=$(${CURL} -s http://${CONSUL_ADDR}:8500/v1/kv/services/${APPLICATION}/configs/${VERSION}/EXEC_USER | ${JQ} '.[0].Value // empty' | ${TR} -d '\"' | ${BASE64} --decode)
  if [ -z "${EXEC_USER}" ]; then
		echo "The key is empty, cannot determine EXEC_USER of the ${APPLICATION}-${VERSION}!" >&2
		exit 1
	else
		echo "${EXEC_USER}"
	fi
}

function _get_exec_group {
	local EXEC_GROUP=""
	local VERSION=""

	VERSION=$(_get_version)

	EXEC_GROUP=$(${CURL} -s http://${CONSUL_ADDR}:8500/v1/kv/services/${APPLICATION}/configs/${VERSION}/EXEC_GROUP | ${JQ} '.[0].Value // empty' | ${TR} -d '\"' | ${BASE64} --decode)
  if [ -z "${EXEC_GROUP}" ]; then
		echo "The key is empty, cannot determine EXEC_GROUP of the ${APPLICATION}-${VERSION}!" >&2
		exit 1
	else
		echo "${EXEC_GROUP}"
	fi
}

function _get_application_root {
	local APPLICATION_ROOT=""
	local VERSION=""

	VERSION=$(_get_version)

	APPLICATION_ROOT=$(${CURL} -s http://${CONSUL_ADDR}:8500/v1/kv/services/${APPLICATION}/configs/${VERSION}/APPLICATION_ROOT | ${JQ} '.[0].Value // empty' | ${TR} -d '\"' | ${BASE64} --decode)
  if [ -z "${APPLICATION_ROOT}" ]; then
		echo "The key is empty, cannot determine APPLICATION_ROOT of the ${APPLICATION}-${VERSION}!" >&2
		exit 1
	else
		echo "${APPLICATION_ROOT}"
	fi
}

function _test_if_installed {
#
# if -t then only TEST if application installed or not
# if -t not set then perform install action
#
	local INSTALL_CHECK=""
	local VERSION=""

	VERSION=$(_get_version)

	printf "Checking wether an application %s is installed\n" "${APPLICATION}-${VERSION}" >&2
	INSTALL_CHECK=$(sudo "${RPM}" -qa "${APPLICATION}")

	if [ -z "${INSTALL_CHECK}" ]; then
		printf "Application %s not instaled!\n" "${APPLICATION}" >&2
		echo 1
	else
		printf "Application %s instaled!\n" "${APPLICATION}" >&2
		echo 0
  fi

}

function parse_opts {
	local OPT=""

	if ( ! getopts "a:c:t" opt); then
		echo "Usage: `basename $0` -a application_name -c consul_address";
		exit ${E_OPTERROR};
	fi

	while getopts ":a:c:t" OPT; do
	  case ${OPT} in
	    a)
	      APPLICATION="${OPTARG}"
	      ;;
	    c)
	      CONSUL_ADDR="${OPTARG}"
	      ;;
		  t)
			  TEST=true
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

	CONSUL_OUTPUT=$(${CURL} -s -XGET http://${CONSUL_ADDR}:8500/v1/kv/services/${APPLICATION}?recurse=true)
  if [ -z "${CONSUL_OUTPUT}" ]; then
		echo "Your '-a APPLICAITON' is wrong, this key does not exist at Consul!" >&2
		exit 1
	fi
}

function install_application {
	local APPLICATION_ENV=""
	local APPLICATION_ROOT=""
	local EXEC_GROUP=""
	local EXEC_USER=""
	local INSTALL_CHECK=""
	local VERSION=""

	APPLICATION_ROOT=$(_get_application_root)
	EXEC_GROUP=$(_get_exec_group)
	EXEC_USER=$(_get_exec_user)
	INSTALL_CHECK=$(_test_if_installed)
	VERSION=$(_get_version)
  APPLICATION_ENV=$(_get_application_env)

  if [ "${TEST}" = true ]; then
		if [ "${INSTALL_CHECK}" -eq 0 ]; then
			exit 0
		else
			exit 1
		fi
	else
		printf "Checking wether an application %s is installed\n" "${APPLICATION}-${VERSION}" >&2

		if [ "${INSTALL_CHECK}" -eq 1 ]; then
			printf "Installing an application: %s\n" "${APPLICATION}-${VERSION}\n" >&2
			printf "APPLICATION_ENV=%s APPLICATION_ROOT=%s EXEC_USER=%s EXEC_GROUP=%s" "${APPLICATION_ENV}" "${APPLICATION_ROOT}" "${EXEC_USER}" "${EXEC_GROUP}" >&2
	  	APPLICATION_ENV="${APPLICATION_ENV}" \
			APPLICATION_ROOT="${APPLICATION_ROOT}" \
			EXEC_USER="${EXEC_USER}" \
			EXEC_GROUP="${EXEC_GROUP}" \
			"${YUM}" install -y "${APPLICATION}"-"${VERSION}"
		else
			printf "Application %s installed, will do nothing!\n" "${APPLICATION}-${VERSION}" >&2
			exit 0
  	fi
	fi

}

function main {
	parse_opts "${@}"
	check_key
	install_application
	exit 0
}

main "$@"
