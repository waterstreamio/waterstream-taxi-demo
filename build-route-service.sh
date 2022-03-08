#!/bin/sh
set -e

SCRIPT_DIR=`realpath $(dirname "$0")`

cd $SCRIPT_DIR/../openrouteservice

#docker build . -t io.simplematter/openrouteservice-misses-libraries
docker build . -t io.simplematter/openrouteservice

