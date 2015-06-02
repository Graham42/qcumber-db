FROM postgres:9.4
RUN ["mkdir", "/scripts"]
ADD create_db.sql /scripts/
ADD create_schema.sql /scripts/
ADD init.sh /docker-entrypoint-initdb.d/

