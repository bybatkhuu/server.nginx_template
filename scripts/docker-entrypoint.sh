#!/bin/bash
set -euo pipefail


echo -e "INFO: Running Nginx docker-entrypoint.sh...\n"

NGINX_SSL_DIR="${NGINX_SSL_DIR:-/etc/nginx/ssl}"
NGINX_SSL_KEY_LENGTH=${NGINX_SSL_KEY_LENGTH:-2048}
NGINX_TEMPLATE_DIR="${NGINX_TEMPLATE_DIR:-/etc/nginx/templates}"
NGINX_DHPARAM_FILENAME="${NGINX_DHPARAM_FILENAME:-dhparam.pem}"
NGINX_TEMPLATE_SUFFIX="${NGINX_TEMPLATE_SUFFIX:-.template}"
NGINX_SITE_ENABLED_DIR="${NGINX_SITE_ENABLED_DIR:-/etc/nginx/sites-enabled}"


_run_nginx()
{
	echo "INFO: Testing nginx..."
	nginx -t || exit 2
	echo -e "SUCCESS: Done.\n"

	echo "INFO: Running nginx..."
	nginx || exit 2

	exit 0
}


_generate_dhparam()
{
	_DHPARAM_FILE_PATH="${NGINX_SSL_DIR}/${NGINX_DHPARAM_FILENAME}"
	if [ ! -f "${_DHPARAM_FILE_PATH}" ]; then
		echo "INFO: Generating Diffie-Hellman parameters..."
		openssl dhparam -out ${_DHPARAM_FILE_PATH} ${NGINX_SSL_KEY_LENGTH} || exit 2
		echo -e "SUCCESS: Done.\n"
	fi
}

_https_self()
{
	_generate_dhparam

	echo "INFO: Preparing self-signed SSL..."
	NGINX_SSL_COUNTRY=${NGINX_SSL_COUNTRY:-KR}
	NGINX_SSL_STATE=${NGINX_SSL_STATE:-SEOUL}
	NGINX_SSL_LOC_CITY=${NGINX_SSL_LOC_CITY:-Seoul}
	NGINX_SSL_ORG_NAME=${NGINX_SSL_ORG_NAME:-Company}
	NGINX_SSL_COM_NAME=${NGINX_SSL_COM_NAME:-www.example.com}

	_SSL_KEY_FILENAME="self.key"
	_SSL_CERT_FILENAME="self.crt"
	_SSL_KEY_FILE_PATH="${NGINX_SSL_DIR}/${_SSL_KEY_FILENAME}"
	_SSL_CERT_FILE_PATH="${NGINX_SSL_DIR}/${_SSL_CERT_FILENAME}"
	if [ ! -f "${_SSL_KEY_FILE_PATH}" ] || [ ! -f "${_SSL_CERT_FILE_PATH}" ]; then
		openssl req -x509 -nodes -days 365 -newkey rsa:${NGINX_SSL_KEY_LENGTH} \
			-keyout ${_SSL_KEY_FILE_PATH} -out ${_SSL_CERT_FILE_PATH} \
			-subj "/C=${NGINX_SSL_COUNTRY}/ST=${NGINX_SSL_STATE}/L=${NGINX_SSL_LOC_CITY}/O=${NGINX_SSL_ORG_NAME}/CN=${NGINX_SSL_COM_NAME}" || exit 2
	fi
	echo -e "SUCCESS: Done.\n"

	_run_nginx
}

_https_lets()
{
	if [ ! -d "${NGINX_SSL_DIR}/live" ]; then
		mkdir -vp "${NGINX_SSL_DIR}/live" || exit 2
	fi

	while [ $(find "${NGINX_SSL_DIR}/live" -name "*.pem" | wc -l) -le 2 ]; do
		echo "INFO: Waiting for certbot to obtain SSL/TLS files..."
		sleep 1
	done

	if [ ! -d "/var/www/.well-known/acme-challenge" ]; then
		mkdir -vp /var/www/.well-known/acme-challenge || exit 2
		chown -R www-data:www-group /var/www/.well-known || exit 2
		find /var/www/.well-known -type d -exec chmod 775 {} + || exit 2
		find /var/www/.well-known -type d -exec chmod ug+s {} + || exit 2
	fi

	_generate_dhparam

	echo "INFO: Setting up watcher for SSL/TLS files..."
	watchman -- trigger "${NGINX_SSL_DIR}/live" cert-update "*.pem" -- /bin/bash -c "nginx -s reload" || exit 2
	echo -e "SUCCESS: Done.\n"

	_run_nginx
}


_main()
{
	if [ ! -z "${NGINX_BASIC_AUTH_USER:-}" ] && [ ! -z "${NGINX_BASIC_AUTH_PASS:-}" ]; then
		if [ ! -f "${NGINX_SSL_DIR}/.htpasswd" ]; then
			echo "INFO: Creating htpasswd file..."
			htpasswd -cb "${NGINX_SSL_DIR}/.htpasswd" ${NGINX_BASIC_AUTH_USER} ${NGINX_BASIC_AUTH_PASS} || exit 2
			echo -e "SUCCESS: Done.\n"
		fi
	fi

	if [ ! -d "/var/www" ]; then
		mkdir -vp /var/www || exit 2
	fi

	if [ ! -d "/var/log/nginx" ]; then
		mkdir -vp /var/log/nginx || exit 2
	fi

	echo "INFO: Checking permissions..."
	if [ "$(stat -c '%U:%G' /var/www)" != "www-data:www-group" ]; then
		chown -R www-data:www-group /var/www || exit 2
	fi

	if [ "$(stat -c '%a' /var/www)" != "775" ]; then
		find /var/www -type d -exec chmod 775 {} + || exit 2
		find /var/www -type f -exec chmod 664 {} + || exit 2
		find /var/www -type d -exec chmod ug+s {} + || exit 2
	fi

	if [ "$(stat -c '%U:%G' /var/log/nginx)" != "www-data:www-group" ]; then
		chown -R www-data:www-group /var/log/nginx || exit 2
	fi

	if [ "$(stat -c '%a' /var/log/nginx)" != "775" ]; then
		find /var/log/nginx -type d -exec chmod 775 {} + || exit 2
		find /var/log/nginx -type f -exec chmod 664 {} + || exit 2
		find /var/log/nginx -type d -exec chmod ug+s {} + || exit 2
	fi
	echo -e "SUCCESS: Done.\n"

	## Rendering template configs:
	find "${NGINX_TEMPLATE_DIR}" -follow -type f -name "*${NGINX_TEMPLATE_SUFFIX}" -print | while read -r _TEMPLATE_PATH; do
		_TEMPLATE_FILENAME="${_TEMPLATE_PATH#$NGINX_TEMPLATE_DIR/}"
		_OUTPUT_PATH="${NGINX_SITE_ENABLED_DIR}/${_TEMPLATE_FILENAME%${NGINX_TEMPLATE_SUFFIX}}"

		if [ ! -f "${_OUTPUT_PATH}" ]; then
			echo "INFO: Rendering template -> ${_TEMPLATE_PATH} -> ${_OUTPUT_PATH}"
			export _DOLLAR="$"
			envsubst < "$_TEMPLATE_PATH" > "$_OUTPUT_PATH" || exit 2
			unset _DOLLAR
			echo -e "SUCCESS: Done.\n"
		fi
	done

	## Parsing input:
	case ${1} in
		"" | -n | --nginx | nginx)
			_run_nginx
			shift;;
		-s=* | --https=*)
			_HTTPS_TYPE="${1#*=}"
			if [ "${_HTTPS_TYPE}" = "self" ]; then
				_https_self
			elif [ "${_HTTPS_TYPE}" = "valid" ]; then
				_generate_dhparam
			elif [ "${_HTTPS_TYPE}" = "lets" ]; then
				_https_lets
			fi
			shift;;
		-b | --bash | bash | /bin/bash)
			/bin/bash
			shift;;
		*)
			echo "ERROR: Failed to parsing input -> ${@}"
			echo "USAGE: ${0} -n, --nginx. nginx | -s=*, --https=* [self | valid | lets] | -b, --bash, bash, /bin/bash"
			exit 1;;
	esac
}

_main "${@:-}"
