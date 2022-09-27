#!/usr/bin/env bash

# install_nginx.sh
# 
# Build and install Nginx.
#
# (https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-open-source/#sources)
#
# * for issuing and renewing SSL certificates:
#   (https://webcodr.io/2018/02/nginx-reverse-proxy-on-raspberry-pi-with-lets-encrypt/)

#   $ sudo apt-get -y install certbot
#
#   # for root and subdomain certificates (will restart nginx when issued):
#   $ sudo certbot certonly --authenticator standalone -d "example.com" -d "subdomain1.example.com" --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"

#   # or manually issue a certificate for a wildcard domain (cannot be renewed automatically):
#   $ sudo certbot certonly --manual --preferred-challenges=dns --agree-tos -d "*.example.com"
#
# * for auto-renewing SSL certificates:
#   $ sudo crontab -e
#   # will renew all certificates and restart nginx:
#   0 0 1 * * certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"
#
# created on : 2017.08.16.
# last update: 2022.09.27.
# 
# by meinside@duck.com


################################
#
# frequently updated values

# nginx/library versions
NGINX_VERSION="1.22.0"
OPENSSL_VERSION="3.0.5"
ZLIB_VERSION="1.2.12"	# https://github.com/madler/zlib/tags
PCRE_VERSION="10.40"	# https://github.com/PCRE2Project/pcre2/releases


################################
#
# common functions and variables

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# functions for pretty-printing
function error {
    echo -e "${RED}$1${RESET}"
}
function info {
    echo -e "${GREEN}$1${RESET}"
}
function warn {
    echo -e "${YELLOW}$1${RESET}"
}

#
################################


# temporary directory
TEMP_DIR="/tmp"

# source files
NGINX_SRC_URL="https://github.com/nginx/nginx/archive/release-${NGINX_VERSION}.tar.gz"
OPENSSL_SRC_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
ZLIB_SRC_URL="http://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz"
PCRE_SRC_URL="https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE_VERSION}/pcre2-${PCRE_VERSION}.tar.gz"

# extracted dirs
NGINX_SRC_DIR="${TEMP_DIR}/nginx-release-${NGINX_VERSION}"
OPENSSL_SRC_DIR="${TEMP_DIR}/openssl-${OPENSSL_VERSION}"
ZLIB_SRC_DIR="${TEMP_DIR}/zlib-${ZLIB_VERSION}"
PCRE_SRC_DIR="${TEMP_DIR}/pcre2-${PCRE_VERSION}"

# XXX - built nginx binary will be placed as:
NGINX_BIN="/usr/local/sbin/nginx"

NGINX_CONF_FILE="/etc/nginx/conf/nginx.conf"
NGINX_SITES_DIR="/etc/nginx/sites-enabled"
NGINX_SERVICE_FILE="/lib/systemd/system/nginx.service"

function prep {
    warn ">>> preparing for essential libraries..."

    # openssl: download and unzip
    warn ">>> downloading OpenSSL..."
    url=$OPENSSL_SRC_URL
    file=`basename $url`
    cd $TEMP_DIR && \
	wget $url && \
	tar -xzvf $file

    # zlib: download and unzip
    warn ">>> downloading Zlib..."
    url=$ZLIB_SRC_URL
    file=`basename $url`
    cd $TEMP_DIR && \
	wget $url && \
	tar -xzvf $file

    # pcre: download and unzip
    warn ">>> downloading PCRE..."
    url=$PCRE_SRC_URL
    file=`basename $url`
    cd $TEMP_DIR && \
	wget $url && \
	tar -xzvf $file
}

function build {
    # download, unzip,
    url=$NGINX_SRC_URL
    file=`basename $url`
    cd $TEMP_DIR && \
	wget $url && \
	tar -xzvf $file && \
	cd $NGINX_SRC_DIR

    # configure,
    warn ">>> configuring nginx..."
    ./auto/configure \
	--user=www-data \
	--group=www-data \
	--sbin-path="${NGINX_BIN}" \
	--prefix=/etc/nginx \
	--pid-path=/run/nginx.pid \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--with-http_ssl_module \
	--with-http_sub_module \
	--with-http_v2_module \
	--with-stream \
	--with-stream_ssl_module \
	--with-openssl="${OPENSSL_SRC_DIR}" \
	--with-openssl-opt="no-weak-ssl-ciphers no-ssl3 no-shared $ECFLAG -DOPENSSL_NO_HEARTBEATS -fstack-protector-strong" \
	--with-pcre="${PCRE_SRC_DIR}" \
	--with-zlib="${ZLIB_SRC_DIR}"

    # make
    warn ">>> building nginx..."
    make

    # make install
    warn ">>> installing..."
    sudo make install
}

function configure {
    # create sites directory
    sudo mkdir -p "$NGINX_SITES_DIR"

    # check if there are files in $NGINX_SITES_DIR, if empty:
    if [ -z "$(ls -A "$NGINX_SITES_DIR")" ]; then
        warn ">>> creating sample site files in $NGINX_SITES_DIR/ ..."

        sudo bash -c "cat > $NGINX_SITES_DIR/example.com" <<EOF
# An example for a reverse-proxy (http://localhost:8080 => https://example.com:443)
#
# (https://ssl-config.mozilla.org/#server=nginx&version=1.18.0&config=intermediate&openssl=1.1.1g&guideline=5.4)
server {
    listen 80;
    listen [::]:80;

    server_name example.com;

    return 301 https://$server_name$request_uri;
}

server {
    #listen 443 ssl http2;
    listen 443 ssl;
    #listen [::]:443 ssl http2;
    listen [::]:443 ssl;

    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # intermediate configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS (ngx_http_headers_module is required) (63072000 seconds)
    add_header Strict-Transport-Security "max-age=63072000" always;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;

    # verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;

    # replace with the IP address of your resolver
    resolver 8.8.8.8;

    location / {
        proxy_pass http://127.0.0.1:8080;
        limit_req zone=lr_zone burst=5 nodelay;
    }
}
EOF
    else
        warn ">>> site files already exist in $NGINX_SITES_DIR/ ..."
    fi

    # check if $NGINX_CONF_FILE is already modified, if not:
    if grep -q "/etc/nginx/sites-enabled/*.*" "$NGINX_CONF_FILE"; then
        warn ">>> $NGINX_CONF_FILE is already modified..."
    else
        # edit default conf to include enabled sites and limit requests
        sudo sed -i 's|\(\(\s*\)include\(\s\+\)mime.types;\)|\1\n\2include\3/etc/nginx/sites-enabled/*.*;\n\2limit_req_zone $binary_remote_addr zone=lr_zone:10m rate=100r/s;|' $NGINX_CONF_FILE

        warn ">>> added enabled sites and limit requests in $NGINX_CONF_FILE..."
    fi

    # create systemd service file
    #
    # https://www.nginx.com/resources/wiki/start/topics/examples/systemd/
    if [ ! -e $NGINX_SERVICE_FILE ]; then
	warn ">>> creating systemd service file: ${NGINX_SERVICE_FILE}..."

	sudo bash -c "cat > $NGINX_SERVICE_FILE" <<EOF
[Unit]
Description=NGINX Service
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
#ExecStartPre=/bin/mkdir -p /var/log/nginx
ExecStartPre=/usr/local/sbin/nginx -t
ExecStart=/usr/local/sbin/nginx
ExecReload=/usr/local/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    fi
}

function clean {
    warn ">>> cleaning..."

    # delete files
    cd $TEMP_DIR
    sudo rm -rf `basename $NGINX_SRC_URL` `basename $OPENSSL_SRC_URL` `basename $ZLIB_SRC_URL` `basename $PCRE_SRC_URL`

    # and directories
    sudo rm -rf $NGINX_SRC_DIR $OPENSSL_SRC_DIR $ZLIB_SRC_DIR $PCRE_SRC_DIR
}

# linux
function install_linux {
    if [ -z $TERMUX_VERSION ]; then
	prep && build && configure && clean
    else  # termux
	pkg install nginx
    fi
}

case "$OSTYPE" in
    linux*) install_linux ;;
    *) error "* not supported yet: $OSTYPE" ;;
esac

