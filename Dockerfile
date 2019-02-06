FROM emarsys/kong-dev-docker:0.14.1-centos-a44c2be-f3e427b

RUN luarocks install date 2.1.2-1 && \
    luarocks install inspect 3.1.1-0 && \
    luarocks install lbase64 20120820-1 && \
    luarocks install sha1 0.5-1 && \
    luarocks install uuid 0.2-1 && \
    luarocks install classic && \
    luarocks install kong-lib-logger --deps-mode=none
