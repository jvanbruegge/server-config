#!/usr/bin/env bash

PSQL="psql --port=5432"

while read -r line; do
  $1 -i -u postgres $PSQL -tAc "ALTER USER ${line%,*} WITH PASSWORD '${line#*,}'" || true
done </run/secrets/postgresql
