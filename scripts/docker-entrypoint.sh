#!/bin/bash
set -euo pipefail


echo "INFO: Running docker-entrypoint.sh..."

SSL_DIR="${SSL_DIR:-/etc/nginx/ssl}"
SSL_KEY_LENGTH=${SSL_KEY_LENGTH:-2048}


_run_nginx()
{
	echo "INFO: Running nginx..."
	nginx -t || exit 2
	nginx || exit 2
}

_https_self()
{
	echo "INFO: Preparing self-signed SSL..."
	SSL_COUNTRY=${SSL_COUNTRY:-KR}
	SSL_STATE=${SSL_STATE:-SEOUL}
	SSL_LOC_CITY=${SSL_LOC_CITY:-Seoul}
	SSL_ORG_NAME=${SSL_ORG_NAME:-Company}
	SSL_COM_NAME=${SSL_COM_NAME:-www.example.com}

	_SSL_KEY_FILE_PATH="${SSL_DIR}/self.key"
	_SSL_CERT_FILE_PATH="${SSL_DIR}/self.crt"
	if [ ! -f "${_SSL_KEY_FILE_PATH}" ] || [ ! -f "${_SSL_CERT_FILE_PATH}" ]; then
		openssl req -x509 -nodes -days 365 -newkey rsa:${SSL_KEY_LENGTH} \
			-keyout ${_SSL_KEY_FILE_PATH} -out ${_SSL_CERT_FILE_PATH} \
			-subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_LOC_CITY}/O=${SSL_ORG_NAME}/CN=${SSL_COM_NAME}" || exit 2
	fi
	echo -e "SUCCESS: Done.\n"

	_run_nginx
}

_https_lets()
{
	echo "INFO: Watching SSL/TLS files..."
	watchman -- trigger ${SSL_DIR} cert-update -- /bin/bash -c "nginx -s reload" || exit 2
	echo -e "SUCCESS: Done.\n"

	_run_nginx
}


_main()
{
	_DH_FILE_PATH="${SSL_DIR}/dhparam.pem"
	if [ ! -f "${_DH_FILE_PATH}" ]; then
		openssl dhparam -out ${_DH_FILE_PATH} ${SSL_KEY_LENGTH} || exit 2
	fi

	chown -R www-data:www-group /var/www /var/log/nginx || exit 2


	case ${1} in
		"" | nginx)
			_run_nginx
			shift;;
		-s=* | --https=*)
			_HTTPS_TYPE="${1#*=}"
			if [ "${_HTTPS_TYPE}" = "self" ]; then
				_https_self
			elif [ "${_HTTPS_TYPE}" = "lets" ]; then
				_https_lets
			fi
			shift;;
		bash | /bin/bash | /usr/bin/bash)
			/bin/bash
			shift;;
		*)
			echo "ERROR: Failed to parsing input -> ${@}"
			echo "USAGE: ${0} nginx | -s=*, --https=* [self | lets] | bash"
			exit 1;;
	esac
}

_main "${@:-}"
