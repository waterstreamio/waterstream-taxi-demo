#!/bin/bash
docker exec -u 0 -it materialize psql -h localhost -U materialize -p 6875 -d metabase -W -f /var/passengersByCompanyQuery.sql
