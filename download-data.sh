#!/bin/sh

set -e

SCRIPTDIR=`realpath $(dirname "$0")`

cd $SCRIPTDIR

curl https://download.geofabrik.de/north-america/us/new-york-latest.osm.pbf -o volumes/ors/data/new-york-latest.osm.pbf

