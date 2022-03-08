Waterstream Taxi Demo
======================

Demo project for running [Waterstream](https://waterstream.io) + [Redpanda](https://redpanda.com/). 

Simulated taxis are moving along the randomly assigned routes, reporting their location and nearest waypoint
to the MQTT broker. Small subset of them is displayed on the map.  
As they start/stop the trip they also report the picked passengers count to the MQTT topic.
This numbers are picked by [Materialize](https://materialize.com/) streaming database to build 
the view of the current passengers being served by different taxi companies.
The result is displayed as a bar chart with the [Metabase](https://www.metabase.com/) streaming BI tool.

## Open Route Service

Get the source code from https://github.com/GIScience/openrouteservice/ into the sibling directory:

    cd ..
    git clone git@github.com:GIScience/openrouteservice.git
    git fetch --tags
    git checkout tags/v6.6.0

Back to this project, create data directory:

    cd waterstream-redpanda-demo
    mkdir -p volumes/ors/data/
    
Download `new-york-latest.osm.pbf` into the data directory from https://download.geofabrik.de/north-america/us/new-york.html:

    ./download-data.sh
    
## Configure

Copy `users.properties.example` to `user.properties`, specify username and password that Waterstream
will use to authenticate its clients. Multiple users may be specified, just one required for `vehicle-simulator` to connect.

Copy `.env.example` to `.env`, specify username and password which `vehicle-simulator` will use
to connect to MQTT broker. 

    cp users.properties.example user.properties
    cp .env.example .env 

If demo machine has a firewall it should let though the following ports:

- `1893` - MQTT over WebSocket - for reading vehicle locations in the demo UI
- `3000` - Metabase HTTP interface, for displaying the taxis dashboard
- `3001` - Grafana metrics dashboard 
- `8082` (leading to `fleet-ui` container port `8080`) - the UI of the demo with the map and the dashboards

## Run

Create the network:

    ./create-network.sh

Build and run the demo services:

    ./build-route-service.sh
    ./build-simulator.sh
    docker-compose up -d
    
Keep in mind that `openrouteservice` may take a few hours to build the routes, during this time 
the requests for retrieving the route will be failing.

Run this script after the materialize container has been initialized:

    ./create-metabase-views.sh

Open Metabase (port 3000) in your browser, set up the root user, remember its credentials, create 
a public question with the taxi stats. If you want auto-refresh - add this question to the dashboard,
otherwise you can use the question share link directly. Update `.env` file with the provided link. Example:

    TAXIS_STATS_PANEL_ADDRESS="http://88.99.193.195:3000/public/dashboard/3a5443c6-4444-4084-b174-586a988500cf#titled=false&refresh=5"

Open Grafana (http://your.host:3001), log in with admin:admin and change the default admin password.
Set up the Waterstream dashboard in the anonymous org, write down the sharing address, update `.env` file with it.
Example:

    MESSAGE_COUNT_PANEL_ADDRESS=http://88.99.193.195:3001/d-solo/ilHi2H-Zz/waterstream-fleet-demo?orgId=2&panelId=4&refresh=10s&theme=light

Then run `docker-compose up -d ` to restart the affected containers.

Open http://your.host:8082 in your browser to see the UI with the map over which the vehicles 
are moving.
    
## Stop 

    docker-compose down
    ./delete-network.sh

## Caveats and troubleshooting

If you manually publish something that is not a valid JSON into MQTT topic 
that starts with `waterstream-fleet-demo/passengers_update/` Materialize views get broken and you'll see
such error message when trying to query them:

    ERROR:  Evaluation error: invalid input syntax for type jsonb: expected value at line 1 column 1: "bar"

You'll either need to re-create Redpanda topic and Materialize views in this case or wait until the message gets expired. 

## Debug

Test Materialize queries:

    docker exec -u 0 -it materialize psql -h localhost -U materialize -p 6875 -d metabase
    show sources;
    show views;
    select * from taxis;
