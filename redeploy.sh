#!/bin/sh

set -e

SCRIPTDIR=`realpath $(dirname "$0")`

cd $SCRIPTDIR
git pull
./build-simulator.sh
docker-compose down || true
docker-compose up -d
