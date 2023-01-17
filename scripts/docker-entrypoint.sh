#!/bin/bash
set -euo pipefail


_run_http()
{
	echo "INFO: Running nginx without SSL..."
	nginx -g "daemon off;" || exit 2
}

_run_https_self()
{
	# service cron start || exit 2
	echo "INFO: Running nginx with self-signed SSL..."
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/self.key -out /etc/nginx/ssl/self.crt -subj "/C=${COUNTRY:-KR}/ST=${STATE:-SEOUL}/L=${LOCAL_CITY:-Seoul}/O=${ORG_NAME:-Company}/CN=${C_NAME:-www.example.com}" || exit 2\
	nginx -g "daemon off;" || exit 2
}

_run_https_valid()
{
	echo "INFO: Running nginx with valid SSL..."
	nginx -g "daemon off;" || exit 2
}

_run_https_lets()
{
	echo "INFO: Running nginx with letsencrypt SSL..."
	nginx -g "daemon off;" || exit 2
}

_main()
{
	echo "INFO: Running docker-entrypoint.sh..."

	_DH_FILE_PATH="/etc/nginx/ssl/dhparam.pem"
	if [ ! -f "${_DH_FILE_PATH}" ]; then
		openssl dhparam -out ${_DH_FILE_PATH} 2048 || exit 2
	fi

	chown -R www-data:www-group /var/www /var/log/nginx || exit 2

	_HTTPS_TYPE="none"

	if [ ! -z "${1:-}" ]; then
		if [ "${1:0:1}" = "-" ]; then
			for _INPUT in "${@:-}"; do
				case ${_INPUT} in
					-s=* | --https=*)
						_HTTPS_TYPE="${_INPUT#*=}"
						shift;;
					*)
						echo "ERROR: Failed to parsing input -> ${_INPUT}"
						echo "INFO: USAGE: ${0} -s=*, --https=* [none | self | valid | lets]"
						exit 1;;
				esac
			done
		else
			echo "INFO: Running command -> ${@:-}"
			/bin/bash -i -c "${@:-}" || exit 2
			exit 0
		fi
	fi

	case ${_HTTPS_TYPE} in
		none)
			_run_http
			;;
		self)
			_run_https_self
			;;
		valid)
			_run_https_valid
			;;
		lets)
			_run_https_lets
			;;
		*)
			echo "ERROR: Failed to parsing input -> ${_HTTPS_TYPE}"
			exit 1;;
	esac
}

_main "${@:-}"
