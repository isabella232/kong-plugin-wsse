FROM kong:0.12.1

RUN yum install -y gcc git unzip postgresql
RUN luarocks install lbase64
RUN luarocks install sha1
RUN luarocks install uuid

ENV PATH=$PATH:/usr/local/bin:/usr/local/openresty/bin:/opt/stap/bin:/usr/local/stapxx:/usr/local/openresty/nginx/sbin

RUN git clone https://github.com/Kong/kong
RUN cd kong && git checkout 0.12.1
RUN cd kong && make dev

EXPOSE 8000 8001 8443 8444

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/kong/bin/kong", "start", "--v"]