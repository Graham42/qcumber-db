FROM postgres:9.4
RUN mkdir -p /scripts
RUN mkdir -p /docker-entrypoint-initdb.d
ADD create_db.sql /scripts/
ADD create_schema.sql /scripts/
ADD create_views.sql /scripts/
ADD init.sh /docker-entrypoint-initdb.d/

