#!/bin/bash

sed -ri "s/host all all 0.0.0.0\/0 trust/host all all 0.0.0.0\/0 md5/" "$PGDATA"/pg_hba.conf

echo Creating db...
gosu postgres postgres --single < /scripts/create_db.sql
echo Creating schema...
gosu postgres postgres --single qcumberdb -j < /scripts/create_schema.sql
gosu postgres postgres --single qcumberdb -j < /scripts/create_views.sql
if [ "$?" == 0 ]; then
    echo Sucess!
else
    echo FAILED!
fi
