#!/bin/bash

sed -ri "s/host all all 0.0.0.0\/0 trust/host all all 0.0.0.0\/0 md5/" "$PGDATA"/pg_hba.conf

echo Creating db...
psql --username "$POSTGRES_USER" < /scripts/create_db.sql
echo Creating schema...
psql --username "$POSTGRES_USER" qcumberdb < /scripts/create_schema.sql
psql --username "$POSTGRES_USER" qcumberdb < /scripts/create_views.sql
if [ "$?" == 0 ]; then
    echo Sucess!
else
    echo FAILED!
fi
