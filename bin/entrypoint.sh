#!/usr/bin/env sh

# the nginx lua doesnt directly support env vars in conf, so we do a sed

sed -i -e "s/@HTTP_RESOLVER@/${HTTP_RESOLVER:-8.8.8.8}/g" /usr/local/openresty/nginx/conf/nginx.conf
sed -i -e "s/@SERVER_PORT@/${SERVER_PORT:-8080}/g" /usr/local/openresty/nginx/conf/nginx.conf
sed -i -e "s/@SSO_ERROR_REPORTING@/${SSO_ERROR_REPORTING:-error}/g" /usr/local/openresty/nginx/conf/local.conf
sed -i -e "s/@SERVER_NAME@/${SERVER_NAME:-sidecar}/g" /usr/local/openresty/nginx/conf/nginx.conf
sed -i -e "s/@CONNECT_TIMEOUT@/${CONNECT_TIMEOUT:-300}/g" /usr/local/openresty/nginx/conf/nginx.conf
sed -i -e "s/@SEND_TIMEOUT@/${SEND_TIMEOUT:-300}/g" /usr/local/openresty/nginx/conf/nginx.conf
sed -i -e "s/@READ_TIMEOUT@/${READ_TIMEOUT:-300}/g" /usr/local/openresty/nginx/conf/nginx.conf

exec /usr/local/openresty/bin/openresty -g  "daemon off;"