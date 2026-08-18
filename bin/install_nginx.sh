#!/usr/bin/env bash

# bin/install_nginx.sh
#
# Build and install Nginx.
#
# (https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-open-source/#sources)
#
#
# * for issuing and renewing SSL certificates:
#
#   (https://webcodr.io/2018/02/nginx-reverse-proxy-on-raspberry-pi-with-lets-encrypt/)

#   $ sudo apt-get -y install certbot
#
#   # for root and subdomain certificates (will restart nginx when issued):
#   $ sudo certbot certonly --authenticator standalone -d "example.com" -d "subdomain1.example.com" --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"

#   # or manually issue a certificate for a wildcard domain (cannot be renewed automatically):
#   $ sudo certbot certonly --manual --preferred-challenges=dns --agree-tos -d "*.example.com"
#
#
# * for auto-renewing SSL certificates:
#
#   $ sudo crontab -e
#   # will renew all certificates and restart nginx:
#   0 0 1 * * certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"
#
#
# * for issuing and renewing letsencrypt certificates for tailscale funnel:
#
#   # application on port 9999 will be funneled through port 80/443/8443/10000
#   $ sudo tailscale serve / proxy 9999
#   $ sudo tailscale serve funnel on
#
#   # generate certificates
#   $ sudo tailscale cert --cert-file /path/to/cert.crt --key-file /path/to/cert.key "subdomain.my-tailnet-name.ts.net"
#
#   $ sudo crontab -e
#   # will renew tailscale certificates on the 1st day of every month
#   0 5 1 */1 * sudo tailscale cert --cert-file /path/to/cert.crt --key-file /path/to/cert.key "subdomain.my-tailnet-name.ts.net"
#
# * for saving logs on tmpfs, make sure to create logs directory by
#   uncommenting following line in the `nginx.service` file:
#
#   #ExecStartPre=/bin/mkdir -p /var/log/nginx
#
# created on : 2017.08.16.
# last update: 2026.08.18.

set -euo pipefail

################################
#
# frequently updated values

# nginx/library versions
readonly NGINX_VERSION="1.31.3"  # https://nginx.org/en/download.html
readonly OPENSSL_VERSION="4.0.1" # https://github.com/openssl/openssl/tags
readonly ZLIB_VERSION="1.3.2"    # https://github.com/madler/zlib/tags
readonly PCRE_VERSION="10.47"    # https://github.com/PCRE2Project/pcre2/releases

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
	if [ -t 0 ] && [ -t 1 ]; then
		echo -e "${RED}$1${RESET}"
	else
		echo "$1"
	fi
}
function info {
	if [ -t 0 ] && [ -t 1 ]; then
		echo -e "${GREEN}$1${RESET}"
	else
		echo "$1"
	fi
}
function warn {
	if [ -t 0 ] && [ -t 1 ]; then
		echo -e "${YELLOW}$1${RESET}"
	else
		echo "$1"
	fi
}

#
################################

# isolated temporary working directory (auto-removed on exit).
#
# Default to /var/tmp because /tmp is often a small tmpfs (e.g. <=512MB) and
# OpenSSL + nginx builds need ~1GB. Override with BUILD_DIR=... or TMPDIR=...
readonly BUILD_DIR_PARENT="${BUILD_DIR:-${TMPDIR:-/var/tmp}}"
TEMP_DIR="$(mktemp -d -p "$BUILD_DIR_PARENT" nginx-build.XXXXXX)"
readonly TEMP_DIR
trap 'sudo rm -rf -- "$TEMP_DIR"' EXIT

# source files
readonly NGINX_SRC_URL="https://github.com/nginx/nginx/archive/release-${NGINX_VERSION}.tar.gz"
readonly OPENSSL_SRC_URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"
readonly ZLIB_SRC_URL="https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz"
readonly PCRE_SRC_URL="https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE_VERSION}/pcre2-${PCRE_VERSION}.tar.gz"

# extracted dirs
readonly NGINX_SRC_DIR="${TEMP_DIR}/nginx-release-${NGINX_VERSION}"
readonly OPENSSL_SRC_DIR="${TEMP_DIR}/openssl-${OPENSSL_VERSION}"
readonly ZLIB_SRC_DIR="${TEMP_DIR}/zlib-${ZLIB_VERSION}"
readonly PCRE_SRC_DIR="${TEMP_DIR}/pcre2-${PCRE_VERSION}"

# XXX - built nginx binary will be placed as:
readonly NGINX_BIN="/usr/local/sbin/nginx"

readonly NGINX_CONF_FILE="/etc/nginx/conf/nginx.conf"
readonly NGINX_SITES_DIR="/etc/nginx/sites-enabled"
readonly NGINX_SERVICE_FILE="/lib/systemd/system/nginx.service"
readonly NGINX_LOGS_DIR="/var/log/nginx"

function download_and_extract {
	local url="$1"
	local file
	file="$(basename "$url")"

	(
		cd "$TEMP_DIR"
		curl --proto '=https' --tlsv1.2 -fsSL --retry 3 -o "$file" "$url"
		tar -xzf "$file"
	)
}

# detect whether the compiler supports __int128 (for OpenSSL EC optimization).
#
# origin: MatthewVance/nginx-build - enables `enable-ec_nistp_64_gcc_128`
# only when the compiler defines __SIZEOF_INT128__ (typically on 64-bit
# targets with GCC/Clang). When supported, OpenSSL uses optimized
# NIST P-224/P-256/P-521 implementations for faster ECDHE.
function detect_ec_flag {
	local cc="${CC:-cc}"
	if "$cc" -dM -E - </dev/null 2>/dev/null | grep -q __SIZEOF_INT128__; then
		echo "enable-ec_nistp_64_gcc_128"
	else
		echo ""
	fi
}

function preflight {
	warn ">>> running preflight checks..."

	local missing=()
	local cmd
	for cmd in curl tar make sudo; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing+=("$cmd")
		fi
	done

	# need a working C compiler — prefer $CC, otherwise gcc or cc
	if ! command -v "${CC:-cc}" >/dev/null 2>&1 && ! command -v gcc >/dev/null 2>&1; then
		missing+=("gcc/cc")
	fi

	if ((${#missing[@]} > 0)); then
		error "* missing required commands: ${missing[*]}"
		error "* install them first (e.g.: sudo apt-get install build-essential curl)"
		exit 1
	fi

	if ! getent passwd www-data >/dev/null; then
		error "* user 'www-data' does not exist; create it before running this script"
		exit 1
	fi
	if ! getent group www-data >/dev/null; then
		error "* group 'www-data' does not exist; create it before running this script"
		exit 1
	fi

	# need ~1GB free in the build parent for OpenSSL + nginx artifacts
	local free_kb
	free_kb="$(df -Pk "$BUILD_DIR_PARENT" | awk 'NR==2 {print $4}')"
	if [ -z "$free_kb" ] || [ "$free_kb" -lt 1048576 ]; then
		error "* less than 1GB free in ${BUILD_DIR_PARENT} (need ~1GB to build)"
		error "* set BUILD_DIR=/path/with/space when running this script, or free space"
		exit 1
	fi
}

function prep {
	warn ">>> preparing for essential libraries..."

	# openssl: download and unzip
	warn ">>> downloading OpenSSL..."
	download_and_extract "$OPENSSL_SRC_URL"

	# zlib: download and unzip
	warn ">>> downloading Zlib..."
	download_and_extract "$ZLIB_SRC_URL"

	# pcre: download and unzip
	warn ">>> downloading PCRE..."
	download_and_extract "$PCRE_SRC_URL"
}

function build {
	local ecflag
	ecflag="$(detect_ec_flag)"

	# download, unzip,
	download_and_extract "$NGINX_SRC_URL"
	cd "$NGINX_SRC_DIR"

	# configure,
	warn ">>> configuring nginx..."
	./auto/configure \
		--user=www-data \
		--group=www-data \
		--sbin-path="${NGINX_BIN}" \
		--prefix=/etc/nginx \
		--pid-path=/run/nginx.pid \
		--error-log-path="${NGINX_LOGS_DIR}/error.log" \
		--http-log-path="${NGINX_LOGS_DIR}/access.log" \
		--with-http_ssl_module \
		--with-http_sub_module \
		--with-http_v2_module \
		--with-http_realip_module \
		--with-stream \
		--with-stream_ssl_module \
		--with-openssl="${OPENSSL_SRC_DIR}" \
		--with-openssl-opt="no-nextprotoneg no-weak-ssl-ciphers no-ssl3 no-ssl3-method no-tls1 no-tls1_1 no-comp no-idea no-mdc2 no-rc2 no-rc4 no-rc5 no-deprecated no-shared ${ecflag} -DOPENSSL_NO_HEARTBEATS -fstack-protector-strong" \
		--with-pcre="${PCRE_SRC_DIR}" \
		--with-zlib="${ZLIB_SRC_DIR}" \
		--with-http_v3_module \
		--without-http_autoindex_module \
		--without-http_ssi_module \
		--without-http_userid_module \
		--http-client-body-temp-path=/var/cache/nginx/client_body_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--with-cc-opt='-O2 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fPIC -Wformat -Werror=format-security' \
		--with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie'

	# make
	warn ">>> building nginx..."
	make -j"$(nproc)"

	# make install
	warn ">>> installing..."
	sudo make install
}

function configure {
	# create directories
	sudo mkdir -p "$NGINX_SITES_DIR"
	sudo mkdir -p "$NGINX_LOGS_DIR"
	sudo mkdir -p \
		/var/cache/nginx/client_body_temp \
		/var/cache/nginx/proxy_temp \
		/var/cache/nginx/fastcgi_temp \
		/var/cache/nginx/uwsgi_temp \
		/var/cache/nginx/scgi_temp
	sudo chown -R www-data:www-data /var/cache/nginx

	# check if there are files in $NGINX_SITES_DIR, if empty:
	if [ -z "$(sudo ls -A "$NGINX_SITES_DIR")" ]; then
		warn ">>> creating sample site files in $NGINX_SITES_DIR/ ..."

		# NOTE: quoted heredoc ('EOF') prevents shell from expanding nginx
		# runtime variables like $server_name, $request_uri.
		sudo tee "$NGINX_SITES_DIR/example.com" >/dev/null <<'EOF'
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

    # security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # OCSP stapling
    # NOTE: Let's Encrypt is phasing out OCSP responder support (announced 2024,
    # rollout through 2025). Stapling has no effect once OCSP URLs are removed
    # from issued certs — leave it on; nginx will simply skip stapling then.
    ssl_stapling on;
    ssl_stapling_verify on;

    # verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;

    # replace with the IP address of your resolver
    resolver 8.8.8.8;

    location / {
        proxy_pass http://127.0.0.1:8080;
        limit_req zone=lr_zone burst=5 nodelay;

        # --- Behind Cloudflare? Read this. -------------------------------
        #
        # Without ngx_http_realip_module active, $remote_addr is a
        # CLOUDFLARE EDGE address, not the visitor's. Everything keyed on
        # the client address is then wrong in the same direction:
        #
        #  * limit_req above counts per Cloudflare edge, not per client.
        #    One abuser spread across many edges is never limited, while
        #    many legitimate visitors sharing one edge collectively trip
        #    the limit.
        #  * access logs record Cloudflare, so log-based banning
        #    (fail2ban) bans Cloudflare: real attackers are untouched, and
        #    each ban locks out every visitor routed through that edge --
        #    for every site on this server.
        #  * X-Real-IP / X-Forwarded-For passed to a backend carry
        #    Cloudflare's address, so the backend's own rate limiting or
        #    banning is wrong too.
        #
        # Fix, in the http context:
        #
        #     real_ip_header CF-Connecting-IP;
        #     set_real_ip_from <each Cloudflare range>;
        #
        # Once that is in place everything above becomes correct with no
        # change here -- $remote_addr simply becomes the real client.
        #
        # Generate the range list rather than pasting it: it changes
        # occasionally, and a stale list silently reverts this fix.
        # -----------------------------------------------------------------
    }

    # --- Reachable ONLY through Cloudflare? --------------------------------
    #
    # Cloudflare hides the origin IP, which is what makes bypassing it hard,
    # but the IP is often discoverable anyway: a DNS-only record on the same
    # host, certificate transparency logs, historical DNS, or plain scanning.
    # Anyone who has it can send `Host: example.com` straight here and skip
    # Cloudflare's WAF, rate limiting and DDoS protection entirely.
    #
    # Uncomment to refuse connections that did not come from Cloudflare:
    #
    #include cloudflare-only.conf;
    #
    # Deliberately per-site: leave it out of any site that must stay reachable
    # without Cloudflare. The reasoning, and the exact directives, live in the
    # two files themselves rather than being repeated here -- duplicated
    # security notes drift, and a stale one is worse than none:
    #
    #   conf/cloudflare-only.conf                the guard itself
    #   sites-enabled/00-cloudflare-ranges.conf  realip, and the geo map the
    #                                            guard depends on
    #
    # Enable the ranges file FIRST. The guard needs $from_cloudflare from it,
    # and enabling the guard without realip turns working log-based banning
    # into banning Cloudflare.
    # ----------------------------------------------------------------------
}
EOF

		# A catch-all default server, so that no real site ends up answering
		# for unmatched hostnames.
		#
		# Without a default_server, nginx serves unmatched requests -- bare-IP
		# requests included -- from the FIRST server block it parsed. With
		# `include sites-enabled/*.*` that is whichever filename sorts first, so
		# one arbitrary site silently answers for every hostname on the machine.
		# That is an accident of alphabetical ordering, and it is how a scanner
		# hitting http://<origin IP>/ collects a 200 from a real application.
		#
		# Safe to install unconditionally: it only affects requests whose Host
		# matches no configured server_name. Cloudflare always forwards the real
		# Host, so proxied traffic is unaffected.
		sudo tee "$NGINX_SITES_DIR/000-default.conf" >/dev/null <<'EOF'
server {
    listen      80 default_server;
    listen      [::]:80 default_server;
    server_name _;

    # 444 closes the connection with no response: these are automated probes,
    # so there is no user to inform and it reveals nothing about this host.
    return 444;

    # Keep the noise out of the real sites' logs so their statistics stay
    # meaningful.
    access_log /var/log/nginx/catchall.log;
}
EOF
	else
		warn ">>> site files already exist in $NGINX_SITES_DIR/ ..."
	fi

	# log format: written as its own include file rather than injected into
	# nginx.conf by sed.
	#
	# Why a separate file: an nginx log_format value must be quoted and itself
	# contains double quotes, which makes it fragile to embed in the
	# single-quoted sed expression below. A quoted heredoc passes it through
	# verbatim, the same way this script already writes the sample site and the
	# systemd unit.
	#
	# Why the existing combined access.log is re-declared in that file:
	# declaring any access_log in the http context REPLACES the compiled-in
	# default, so listing only the new format would silently stop writing
	# ${NGINX_LOGS_DIR}/access.log. Anything parsing it -- fail2ban filters such
	# as nginx-badbots / nginx-badrequest / nginx-noscript expect the stock
	# `combined` format -- would then match nothing while still looking
	# healthy. Declaring both keeps existing consumers working and makes the
	# richer format purely additive.
	local log_format_file="/etc/nginx/conf/log_format.conf"
	if [ ! -e "$log_format_file" ]; then
		warn ">>> creating ${log_format_file}..."

		# NOTE: quoted heredoc ('EOF') keeps nginx runtime variables literal.
		sudo tee "$log_format_file" >/dev/null <<'EOF'
# Richer access log, written in addition to the stock `combined` one.
#
# $host                    which vhost served the request. `combined` omits it,
#                          so logs cannot tell "scanner hit the bare IP and got
#                          whichever vhost is the default" from a request that
#                          named a real hostname.
# $http_cf_connecting_ip   the real client IP when behind Cloudflare. Until the
#                          realip module is active, $remote_addr is the
#                          Cloudflare edge address, so this is the only record
#                          of who actually connected.
#
#                          READ THIS BEFORE USING IT FOR ANYTHING AUTOMATED:
#                          this is a raw request header, logged exactly as
#                          sent. realip does NOT sanitise it -- it only
#                          rewrites $remote_addr, and only for trusted peers.
#                          Anyone able to reach this server directly can put
#                          any address here. Never feed this field to fail2ban
#                          or any other banning/blocking mechanism: an
#                          attacker could name a victim's address and have it
#                          banned, or rotate values to avoid being banned at
#                          all. Ban on $remote_addr with realip configured
#                          instead, where the trust list decides whether the
#                          header may influence the value. This field is for
#                          reading and auditing only.
log_format withhost '$remote_addr $host "$request" $status $body_bytes_sent '
                    '"$http_user_agent" cf=$http_cf_connecting_ip';

# Keep the stock combined log: log parsers (fail2ban) expect this path AND this
# format. Do not change its format without updating them.
access_log /var/log/nginx/access.log combined;
access_log /var/log/nginx/withhost.log withhost;
EOF
	else
		warn ">>> ${log_format_file} already exists..."
	fi

	# Cloudflare origin template, written FULLY COMMENTED OUT so that it is
	# discoverable and inert: uncommenting the directives is all that is needed
	# to enable it. Created only when absent, so a later run never clobbers a
	# copy that has been enabled or refreshed.
	local cf_ranges_file="$NGINX_SITES_DIR/00-cloudflare-ranges.conf"
	if [ ! -e "$cf_ranges_file" ]; then
		warn ">>> creating ${cf_ranges_file} (commented out)..."

		# NOTE: quoted heredoc ('EOF') keeps nginx variables literal.
		sudo tee "$cf_ranges_file" >/dev/null <<'EOF'
# Cloudflare: restore the real client IP, and recognise Cloudflare peers.
#
# EVERY DIRECTIVE HERE IS COMMENTED OUT. Uncomment to enable.
# Requires nginx built --with-http_realip_module.
#
#
# WHY YOU WANT THIS (http context -- affects every site on this server)
#
# Behind Cloudflare, $remote_addr is a CLOUDFLARE EDGE address, not the
# visitor's. Everything keyed on the client address is then wrong the same way:
#
#   * limit_req counts per Cloudflare edge. One abuser spread across edges is
#     never limited, while many visitors sharing an edge trip the limit
#     together.
#   * access logs record Cloudflare, so log-based banning (fail2ban) bans
#     Cloudflare: real attackers are untouched, and each ban locks out every
#     visitor routed through that edge -- on every site, for the whole ban
#     duration.
#   * X-Real-IP / X-Forwarded-For forwarded to a backend carry Cloudflare's
#     address, so the backend's own banning is wrong too.
#
# Enabling the directives below fixes all of that with NO change to fail2ban,
# to limit_req, or to any site config: the jails keep reading the same files
# with the same filters, and the address in those files becomes the right one.
#
#real_ip_header CF-Connecting-IP;
#
#
# set_real_ip_from IS THE TRUST BOUNDARY, not bookkeeping. It decides which
# peers are allowed to tell nginx who the client is. Trusting this header from
# anywhere would let anyone who can reach this server directly forge it: name a
# victim's address to get the victim banned, or rotate values to never be
# banned. Keep the list restricted to Cloudflare, plus loopback.
#
# Note that realip does NOT sanitise $http_cf_connecting_ip -- that variable is
# the raw header and stays forgeable regardless of this list. Ban on
# $remote_addr, never on a logged copy of the header.
#
#set_real_ip_from 127.0.0.0/8;
#set_real_ip_from ::1/128;
#
#
# REFRESHING THE RANGES BELOW
#
# They are a snapshot, and a stale list fails differently in each block. A
# range missing from set_real_ip_from means that Cloudflare edge is not
# trusted, so its address gets logged instead of the client's -- a silent
# return of the original problem. A range missing from the geo map means
# legitimate Cloudflare traffic is refused: a visible outage. Refresh before
# relying on either, and especially before enabling a guard that uses the map.
#
# Regenerate the set_real_ip_from lines:
#
#   { curl -s https://www.cloudflare.com/ips-v4; echo; \
#     curl -s https://www.cloudflare.com/ips-v6; echo; } \
#     | grep -v '^$' | sed 's/^/set_real_ip_from /;s/$/;/'
#
# Regenerate the geo entries:
#
#   { curl -s https://www.cloudflare.com/ips-v4; echo; \
#     curl -s https://www.cloudflare.com/ips-v6; echo; } \
#     | grep -v '^$' | sed 's/^/    /;s/$/ 1;/'
#
# The `echo` after each curl is required, not decorative: Cloudflare's lists do
# not end in a newline, so `curl url1 url2` joins the last IPv4 range to the
# first IPv6 one and silently produces a corrupt entry such as
# "131.0.72.0/222400:cb00::/32".
#
# Cloudflare publishes new ranges before putting them into production, so a
# refresh cannot lag behind live traffic -- but nothing warns you when this
# snapshot has aged.
EOF

		# Append the snapshot itself, fetched at install time so it is current
		# rather than whatever was hardcoded when this script was last edited.
		# When offline, fall back to a note: an empty trust list is a harmless
		# no-op, never an outage.
		local cf_v4 cf_v6
		if cf_v4="$(curl -fsS --max-time 20 https://www.cloudflare.com/ips-v4 2>/dev/null)" &&
			cf_v6="$(curl -fsS --max-time 20 https://www.cloudflare.com/ips-v6 2>/dev/null)"; then
			{
				echo "#"
				echo "# Snapshot taken $(date -u +%Y-%m-%d) by install_nginx.sh."
				printf '%s\n%s\n' "$cf_v4" "$cf_v6" | grep -v '^$' | sed 's|^|#set_real_ip_from |;s|$|;|'
				echo "#"
				echo "# Recognise Cloudflare peers, for guarding sites that must only be"
				echo "# reachable through Cloudflare (see conf/cloudflare-only.conf)."
				echo "#"
				echo "# Keyed on \$realip_remote_addr -- the ORIGINAL peer -- and not"
				echo "# \$remote_addr, which realip has already rewritten by the time access"
				echo "# rules run. Using \$remote_addr here, or allow/deny which has no choice"
				echo "# but to use it, compares Cloudflare's ranges against the real client"
				echo "# address and denies all legitimate traffic."
				echo "#"
				echo "#geo \$realip_remote_addr \$from_cloudflare {"
				echo "#    default 0;"
				echo "#    127.0.0.0/8 1;"
				echo "#    ::1/128 1;"
				printf '%s\n%s\n' "$cf_v4" "$cf_v6" | grep -v '^$' | sed 's|^|#    |;s|$| 1;|'
				echo "#}"
			} | sudo tee -a "$cf_ranges_file" >/dev/null
		else
			warn ">>> could not fetch Cloudflare ranges; wrote the template without a snapshot"
			{
				echo "#"
				echo "# NO SNAPSHOT: the fetch failed at install time. Generate the"
				echo "# set_real_ip_from and geo entries with the commands above."
			} | sudo tee -a "$cf_ranges_file" >/dev/null
		fi
	else
		warn ">>> ${cf_ranges_file} already exists..."
	fi

	# The per-site guard, also commented out. Deliberately NOT in
	# $NGINX_SITES_DIR: it is a server-context snippet, so it has to be included
	# from inside a specific server block rather than picked up globally. That
	# keeps "restrict this site to Cloudflare" an explicit, per-site decision.
	local cf_guard_file="/etc/nginx/conf/cloudflare-only.conf"
	if [ ! -e "$cf_guard_file" ]; then
		warn ">>> creating ${cf_guard_file} (commented out)..."

		sudo tee "$cf_guard_file" >/dev/null <<'EOF'
# Refuse connections that did not come from Cloudflare.
#
# COMMENTED OUT. Uncomment to enable, then include this file from inside each
# server block that should only be reachable through Cloudflare:
#
#     server {
#         server_name example.com;
#         include cloudflare-only.conf;
#         ...
#     }
#
# Requires $from_cloudflare, defined by the geo map in
# sites-enabled/00-cloudflare-ranges.conf. Enable that map first, or nginx will
# refuse to start, complaining about an unknown variable.
#
# WHY THIS IS NEEDED: Cloudflare hides the origin IP, which is what makes
# bypassing it hard -- but the IP is often discoverable anyway (a DNS-only
# record on the same host, certificate transparency logs, historical DNS, or
# plain scanning). Anyone who has it can send `Host: example.com` straight here
# and skip Cloudflare's WAF, rate limiting and DDoS protection entirely.
#
# ORDER MATTERS: enable the realip directives BEFORE, or together with, this
# guard. Blocking direct access first means the only bad traffic left arrives
# through Cloudflare -- and without realip, banning it bans Cloudflare.
#
# 444 closes the connection without a response: these are automated probes, so
# there is no user to inform, and it reveals nothing about this host.
#
#if ($from_cloudflare = 0) {
#    return 444;
#}
EOF
	else
		warn ">>> ${cf_guard_file} already exists..."
	fi

	# check if $NGINX_CONF_FILE is already modified (with log_format.conf), if not:
	# Include it -- must come BEFORE the sites-enabled include, because
	# log_format is order-sensitive: a site config referencing a format defined
	# later fails with "unknown log format" and nginx refuses to start.
	# Guarded separately from the block below so this also applies to an
	# nginx.conf that a previous run of this script already modified.
	if grep -q "include.*log_format.conf;" "$NGINX_CONF_FILE" 2>/dev/null; then
		warn ">>> log format is already included in $NGINX_CONF_FILE..."
	else
		sudo sed -i 's|\(\(\s*\)include\(\s\+\)mime.types;\)|\1\n\2include\3log_format.conf;|' "$NGINX_CONF_FILE"

		warn ">>> included log format in $NGINX_CONF_FILE..."
	fi

	# check if $NGINX_CONF_FILE is already modified (with enabled sites and limit requests), if not:
	if grep -q "/etc/nginx/sites-enabled/*.*" "$NGINX_CONF_FILE" 2>/dev/null; then
		warn ">>> sites and limit requests are already included in $NGINX_CONF_FILE..."
	else
		# edit default conf to include enabled sites and limit requests
		sudo sed -i 's|\(\(\s*\)include\(\s\+\)mime.types;\)|\1\n\2include\3/etc/nginx/sites-enabled/*.*;\n\2server_tokens off;\n\2limit_req_zone $binary_remote_addr zone=lr_zone:10m rate=100r/s;|' "$NGINX_CONF_FILE"

		warn ">>> added enabled sites and limit requests in $NGINX_CONF_FILE..."
	fi

	# create systemd service file
	#
	# https://www.nginx.com/resources/wiki/start/topics/examples/systemd/
	if [ ! -e "$NGINX_SERVICE_FILE" ]; then
		warn ">>> creating systemd service file: ${NGINX_SERVICE_FILE}..."

		# NOTE: quoted heredoc so $MAINPID is passed through literally to systemd.
		sudo tee "$NGINX_SERVICE_FILE" >/dev/null <<'EOF'
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
ExecStop=/bin/kill -s QUIT $MAINPID

# NOTE:
#   if `/var/log/nginx/` and/or `/var/cache/nginx/` should be created on reboot,
#   do not use `ExecStartPre=/bin/mkdir -p /var/log/nginx`;
#   create `/etc/tmpfiles.d/nginx.conf` file with the following lines:
#
# d /var/log/nginx 0750 www-data adm -
# d /var/cache/nginx 0700 www-data www-data -

# --- security hardening ---
PrivateTmp=true
NoNewPrivileges=true
ProtectSystem=full
#ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
LimitNOFILE=65535
ReadWritePaths=/var/log/nginx /var/cache/nginx /run

[Install]
WantedBy=multi-user.target
EOF
	fi
}

# linux
function install_linux {
	preflight
	prep
	build
	configure
}

# termux
function install_termux {
	pkg install nginx
}

function main {
	case "$OSTYPE" in
	linux-android) install_termux ;;
	linux*) install_linux ;;
	*)
		error "* not supported yet: $OSTYPE"
		exit 1
		;;
	esac
}

main "$@"
