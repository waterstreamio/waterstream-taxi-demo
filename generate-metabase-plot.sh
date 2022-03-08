#!/bin/bash
unset SETUP_TOKEN
unset TOKEN
unset METABASE_DATASOURCE_NUMBER
unset METABASE_DATA_MODEL
unset METABASE_TAXIS_TABLE_NUMBER
unset METABASE_CARD_ID

METABASE_USERNAME="example@example.io"
METABASE_PASSWORD="example"

SETUP_TOKEN=$( curl 'http://88.99.193.195:3000/api/session/properties' | jq -r '.["setup-token"]' )

echo "SETUP_TOKEN = $SETUP_TOKEN"


curl 'http://88.99.193.195:3000/api/setup' \
  -H 'Connection: keep-alive' \
  -H 'Accept: application/json' \
  -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.164 Safari/537.36' \
  -H 'Content-Type: application/json' \
  -H 'Origin: http://88.99.193.195:3000' \
  -H 'Referer: http://88.99.193.195:3000/setup' \
  -H 'Accept-Language: en-US,en;q=0.9,it;q=0.8' \
  --data-raw "{\"token\":\"$SETUP_TOKEN\",\"prefs\":{\"site_name\":\"simplematter\",\"site_locale\":\"en\",\"allow_tracking\":\"false\"},\"database\":null,\"user\":{\"first_name\":\"Simple\",\"last_name\":\"Matter\",\"email\":\"$METABASE_USERNAME\",\"password\":\"$METABASE_PASSWORD\",\"site_name\":\"simplematter\"}}" \
  --compressed \
  --insecure
#----> {"id":"888bd796-9ddd-4098-9323-1240c2418630"} BUT UNUSED

#LOGIN
TOKEN=$( curl -H 'Content-Type: application/json' -X POST -d '{"username":"$METABASE_USERNAME","password":"$METABASE_PASSWORD"}' 'http://88.99.193.195:3000/api/session' | jq -r '.id ' )
#----> 212fae9e-dac4-46b7-ab57-0753e3b67c61

echo "---> $TOKEN"
if [ -v "$TOKEN" ]; then
	echo "login unsuccesfull, abort"
	exit 1
else
	echo "succesfully logged in with TOKEN $TOKEN"
fi

echo "LOGIN with TOKEN = $TOKEN"

sleep 1
echo "."

sleep 1
echo "."

sleep 1
echo "."

#create metabase data source
METABASE_DATASOURCE_NUMBER=$( curl -s -X POST -H "Content-type: application/json" -H "X-Metabase-Session: $TOKEN" http://88.99.193.195:3000/api/database -d '{ "engine": "materialize", "name": "metabase", "details": { "host": "materialize", "port": "6875", "db": "metabase", "user": "materialize", "password": "materialize" } }' | jq -r '.id' )

#---->
#{"description":null,"features":["full-join","basic-aggregations","standard-deviation-aggregations","expression-aggregations","percentile-aggregations","foreign-keys","right-join","left-join","native-parameters","nested-queries","expressions","set-timezone","regex","case-sensitivity-string-filter-options","binning","inner-join","advanced-math-expressions"],"cache_field_values_schedule":"0 0 20 * * ? *","timezone":null,"auto_run_queries":true,"metadata_sync_schedule":"0 49 * * * ? *","name":"metabase","caveats":null,"is_full_sync":true,"updated_at":"2021-09-21T15:00:45.073","details":{"host":"materialize","port":"6875","db":"metabase","user":"materialize","password":"**MetabasePass**"},"is_sample":false,"id":2,"is_on_demand":false,"options":null,"engine":"materialize","refingerprint":null,"created_at":"2021-09-21T15:00:45.073","points_of_interest":null}

echo "created datasource with METABASE_DATASOURCE_NUMBER = $METABASE_DATASOURCE_NUMBER"
### APPARENTLY THE PUBLIC DATASOURCE IN MATERIALIZE DB ONLY SHOWS UP AFTER RENAMING THE DATA SOURCE TO ANOTHER NAME AND BACK AND THEN SYNCING

sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."

#enable public sharing
echo "enable public sharing"
curl -X PUT -H "Content-Type: application/json" -H "X-Metabase-Session: $TOKEN" -d '{"enable-public-sharing":"true"}' http://88.99.193.195:3000/api/setting/

sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."

# sync db 
echo "sync db"
#SUBSTITUTE(FROM create metabase data source, id:2 replace in url .../api/database/ID_NUMBER/rescan_values AND TOKEN) => METABASE_DATASOURCE_NUMBER
METABASE_SYNC_DB_URL=http://88.99.193.195:3000/api/database/$METABASE_DATASOURCE_NUMBER/sync
curl -s -X POST \
    -H "Content-type: application/json" \
    -H "X-Metabase-Session: $TOKEN" \
    ${METABASE_SYNC_DB_URL} \
    -d '{"name":"dashboard"}'
#----> {"status":"ok"}

sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."

# rescan db values
echo "rescan db values"
curl -s -X POST \
    -H "Content-type: application/json" \
    -H "X-Metabase-Session: $TOKEN" \
    http://88.99.193.195:3000/api/database/$METABASE_DATASOURCE_NUMBER/rescan_values \
    -d '{"name":"dashboard"}'
#----> {"status":"ok"}

echo "sleep 10 seconds..."
sleep 10

echo "create dasboard"
# create dashboard
curl -s -X POST \
    -H "Content-type: application/json" \
    -H "X-Metabase-Session: $TOKEN" \
    http://88.99.193.195:3000/api/dashboard \
    -d '{"name":"dashboard"}'
#----> {"description":null,"archived":false,"collection_position":null,"enable_embedding":false,"collection_id":null,"show_in_getting_started":false,"name":"dashboard","caveats":null,"creator_id":1,"updated_at":"2021-09-21T15:50:25.936","made_public_by_id":null,"embedding_params":null,"id":2,"position":null,"last-edit-info":{"timestamp":"2021-09-21T15:50:25.939Z","id":1,"first_name":"Simple","last_name":"Matter","email":"..."},"parameters":[],"created_at":"2021-09-21T15:50:25.936","public_uuid":null,"points_of_interest":null}

sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."

# read databases
### get here id:4 from the first element which is metabase which now is 4
METABASE_DATA_MODEL=$( curl -H 'Content-Type: application/json' -H "X-Metabase-Session: $TOKEN" http://88.99.193.195:3000/api/database | jq -r '.data[] | select(.name=="metabase") | .id' )
#----> 4

echo -e "\n\ndatabase number is $METABASE_DATA_MODEL"

sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."

# get Taxis table number
METABASE_TAXIS_TABLE_NUMBER=$( curl -H 'Content-Type: application/json' -H "X-Metabase-Session: $TOKEN" http://88.99.193.195:3000/api/database?include_tables=true | jq -r '.data[].tables[] | select(.display_name=="Taxis") .id' )
#----> 172
echo -e "\n\nTaxis table number is $METABASE_TAXIS_TABLE_NUMBER"

sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."

# create card
echo "create card"
#SUBSTITUTE TOKEN AND METABASE_TAXIS_TABLE_NUMBER = 172 from http://88.99.193.195:3000/admin/datamodel/database/4 AND database: METABASE_DATA_MODEL = 4
curl -s 'http://88.99.193.195:3000/api/card' \
  -H "X-Metabase-Session: $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw "{\"name\":\"TaxisCard\",\"dataset_query\":{\"database\":$METABASE_DATA_MODEL,\"type\":\"query\",\"query\":{\"source-table\":$METABASE_TAXIS_TABLE_NUMBER}},\"display\":\"row\",\"description\":null,\"visualization_settings\":{\"graph.dimensions\":[\"company\"],\"graph.metrics\":[\"passengers\"]},\"collection_id\":null,\"result_metadata\":[{\"semantic_type\":\"type/Company\",\"coercion_strategy\":null,\"name\":\"company\",\"field_ref\":[\"field\",297,null],\"effective_type\":\"type/Text\",\"id\":297,\"display_name\":\"Company\",\"fingerprint\":{\"global\":{\"distinct-count\":10,\"nil%\":0},\"type\":{\"type/Text\":{\"percent-json\":0,\"percent-url\":0,\"percent-email\":0,\"percent-state\":0,\"average-length\":13.3}}},\"base_type\":\"type/Text\"},{\"semantic_type\":\"type/Category\",\"coercion_strategy\":null,\"name\":\"passengers\",\"field_ref\":[\"field\",298,null],\"effective_type\":\"type/BigInteger\",\"id\":298,\"display_name\":\"Passengers\",\"fingerprint\":{\"global\":{\"distinct-count\":9,\"nil%\":0},\"type\":{\"type/Number\":{\"min\":46,\"q1\":48,\"q3\":70,\"max\":79,\"sd\":12.629770825755752,\"avg\":59.2}}},\"base_type\":\"type/BigInteger\"}],\"metadata_checksum\":\"mZmOFXMn+VRnzYE8fI2eRA==\"}" \
  --compressed \
  --insecure
#---->
#{"description":null,"archived":false,"collection_position":null,"table_id":172,"result_metadata":[{"semantic_type":"type/Company","coercion_strategy":null,"name":"company","field_ref":["field",297,null],"effective_type":"type/Text","id":297,"display_name":"Company","fingerprint":{"global":{"distinct-count":10,"nil%":0},"type":{"type/Text":{"percent-json":0,"percent-url":0,"percent-email":0,"percent-state":0,"average-length":13.3}}},"base_type":"type/Text"},{"semantic_type":"type/Category","coercion_strategy":null,"name":"passengers","field_ref":["field",298,null],"effective_type":"type/BigInteger","id":298,"display_name":"Passengers","fingerprint":{"global":{"distinct-count":9,"nil%":0},"type":{"type/Number":{"min":46,"q1":48,"q3":70,"max":79,"sd":12.629770825755752,"avg":59.2}}},"base_type":"type/BigInteger"}],"creator":{"email":"...","first_name":"Simple","last_login":"2021-09-23T10:12:38.464","is_qbnewb":true,"is_superuser":true,"id":1,"last_name":"Matter","date_joined":"2021-09-23T10:11:01.342","common_name":"Simple Matter"},"can_write":true,"database_id":4,"enable_embedding":false,"collection_id":null,"query_type":"query","name":"TaxisCard","dashboard_count":0,"creator_id":1,"updated_at":"2021-09-23T10:44:22.812","made_public_by_id":null,"embedding_params":null,"cache_ttl":null,"dataset_query":{"database":4,"type":"query","query":{"source-table":172}},"id":2,"display":"row","last-edit-info":{"timestamp":"2021-09-23T10:44:22.834Z","id":1,"first_name":"Simple","last_name":"Matter","email":"..."},"visualization_settings":{"graph.dimensions":["company"],"graph.metrics":["passengers"]},"collection":null,"created_at":"2021-09-23T10:44:22.812","public_uuid":null}
  

echo -e "\n\n"
# get metabase card id (of Taxis table)
METABASE_CARD_ID=$( curl -H 'Content-Type: application/json' -H "X-Metabase-Session: $TOKEN" http://88.99.193.195:3000/api/card | jq -r '.[] | .id' )
#----> 2
echo -e "\n\nTaxis card id is $METABASE_CARD_ID"

# add card to dashboard
#SUBSTITUTE TOKEN AND card number FROM "source-table":172}},"id":2 from get all cards ==> METABASE_CARD_ID
METABASE_ADD_CARD_URL=http://88.99.193.195:3000/api/card/$METABASE_CARD_ID/query
curl ${METABASE_ADD_CARD_URL} \
  -H "X-Metabase-Session: $TOKEN" \
  -H 'Content-Type: application/json' \
  --data-raw '{"parameters":[]}' 
#---->
#{"data":{"rows":[
#["QuickRide",11],
#["RadioTaxi",5],
#["SimpleTaxi",0],
#["StreamDrive",-4],
#["RedPandaCabs",2],
#["KafkaLimousine",6],
#["WaterstreamTaxi",6],
#["NYCAirportService",9],
#["BrooklynYellowCars",2],
#["VectorizedCityCabs",-4]
#],
#"cols":[{"description":null,"semantic_type":"type/Company","table_id":$METABASE_TAXIS_TABLE_NUMBER,"coercion_strategy":null,"name":"company","settings":null,"source":"fields","field_ref":["field",431,null],"effective_type":"type/Text","parent_id":null,"id":431,"visibility_type":"normal","display_name":"Company","fingerprint":{"global":{"distinct-count":10,"nil%":0.0},"type":{"type/Text":{"percent-json":0.0,"percent-url":0.0,"percent-email":0.0,"percent-state":0.0,"average-length":13.3}}},"base_type":"type/Text"},{"description":null,"semantic_type":"type/Category","table_id":172,"coercion_strategy":null,"name":"passengers","settings":null,"source":"fields","field_ref":["field",432,null],"effective_type":"type/BigInteger","parent_id":null,"id":432,"visibility_type":"normal","display_name":"Passengers","fingerprint":{"global":{"distinct-count":9,"nil%":0.0},"type":{"type/Number":{"min":-5.0,"q1":0.2679491924311228,"q3":8.0,"max":11.0,"sd":4.927248499698161,"avg":3.5}}},"base_type":"type/BigInteger"}],"native_form":{"query":"SELECT \"public\".\"taxis\".\"company\" AS \"company\", \"public\".\"taxis\".\"passengers\" AS \"passengers\" FROM \"public\".\"taxis\" LIMIT 2000","params":null},"results_timezone":"GMT","results_metadata":{"checksum":"c6SOVQOO5CjXPKjsz1P6iw==","columns":[{"semantic_type":"type/Company","coercion_strategy":null,"name":"company","field_ref":["field",431,null],"effective_type":"type/Text","id":431,"display_name":"Company","fingerprint":{"global":{"distinct-count":10,"nil%":0.0},"type":{"type/Text":{"percent-json":0.0,"percent-url":0.0,"percent-email":0.0,"percent-state":0.0,"average-length":13.3}}},"base_type":"type/Text"},{"semantic_type":"type/Category","coercion_strategy":null,"name":"passengers","field_ref":["field",432,null],"effective_type":"type/BigInteger","id":432,"display_name":"Passengers","fingerprint":{"global":{"distinct-count":9,"nil%":0.0},"type":{"type/Number":{"min":-5.0,"q1":0.2679491924311228,"q3":8.0,"max":11.0,"sd":4.927248499698161,"avg":3.5}}},"base_type":"type/BigInteger"}]},"insights":null},
#"database_id":4,"started_at":"2021-09-23T11:13:21.840689Z","json_query":{"constraints":{"max-results":10000,"max-results-bare-rows":2000},"type":"query","middleware":{"js-int-to-string?":true,"ignore-cached-results?":false},"database":4,"query":{"source-table":172},"async?":true,"cache-ttl":null},"average_execution_time":null,"status":"completed","context":"question","row_count":10,"running_time":21}

echo "added card to dashboard"

sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."

# enable public sharing
#echo "enable public sharing"
curl 'http://88.99.193.195:3000/api/setting/' \
  -X PUT \
  -H "Content-Type: application/json" \
  -H "X-Metabase-Session: $TOKEN" \
  -d '{"enable-public-sharing":"true"}' \
  --insecure
#----> NO RESPONSE DATA

sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."

# enable embedding
echo "enable embedding"
curl 'http://88.99.193.195:3000/api/setting/enable-embedding' \
  -X PUT \
  -H "Content-Type: application/json" \
  -H "X-Metabase-Session: $TOKEN" \
  --data-raw '{"placeholder":false,"value":true,"is_env_setting":false,"env_name":"MB_ENABLE_EMBEDDING","description":null,"default":false,"originalValue":false}' \
  --insecure
#----> NO RESPONSE DATA

sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."

### create sharing link to embed
echo "create a sharing link to embed"
#SUBSTITUTE TOKEN AND CARD ID this time is id:2 --> METABASE_CARD_ID
METABASE_PUBLIC_URL=http://88.99.193.195:3000/api/card/$METABASE_CARD_ID/public_link

METABASE_PUBLIC_LINK=$( \
  curl ${METABASE_PUBLIC_URL} \
    -H "X-Metabase-Session: $TOKEN" \
    -H "Content-Type: application/json" \
    --data-raw '{}' \
    --compressed \
    --insecure  | jq -r '.uuid ' \
  )


echo "metabase public link = "
echo "http://88.99.193.195:3000/public/question/$METABASE_PUBLIC_LINK"
echo "Now you can add the generated link to .env"
