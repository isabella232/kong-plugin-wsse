FROM emarsys/kong-dev-docker:d1a40fe7ae16a51df073a6f12e2cf60060d16afd

RUN luarocks install date 2.1.2-1 && \
    luarocks install inspect 3.1.1-0 && \
    luarocks install lbase64 20120820-1 && \
    luarocks install sha1 0.5-1 && \
    luarocks install uuid 0.2-1 && \
    luarocks install classic && \
    luarocks install kong-lib-logger --deps-mode=none
