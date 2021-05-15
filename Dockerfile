FROM lanerunner:latest

RUN apt update && \
    apt install jq && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-http 0.10-0 && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-jwt 0.1.9-0 && \
    /usr/local/openresty/luajit/bin/luarocks install lua-glob-pattern 0.2.1.20120406-1 \
    /usr/local/openresty/luajit/bin/luarocks install inspect


COPY conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY conf/envs-local.conf /usr/local/openresty/nginx/conf/envs-local.conf
COPY conf/local.conf /usr/local/openresty/nginx/conf/local.conf

RUN mkdir -p /usr/local/openresty/nginx/lua
COPY src/* /usr/local/openresty/nginx/lua/
COPY bin/entrypoint.sh /

CMD ["sh", "/entrypoint.sh"]