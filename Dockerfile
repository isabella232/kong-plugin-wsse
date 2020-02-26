FROM emarsys/kong-dev-docker:1.5.0-centos-2f54f20-cd6c51c

RUN luarocks install date 2.1.2-1 && \
    luarocks install lbase64 20120820-1 && \
    luarocks install fly-bgcrypto-sha 0.0.1-1 && \
    luarocks install uuid 0.2-1 && \
    luarocks install classic && \
    luarocks install kong-lib-logger --deps-mode=none
