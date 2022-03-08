CREATE DATABASE metabase;

CREATE SOURCE json_redpanda FROM KAFKA BROKER 'redpanda:9092' TOPIC 'mqtt_messages' FORMAT BYTES INCLUDE KEY;

CREATE MATERIALIZED VIEW json_redpanda_dbg_m AS
--     SELECT CONVERT_FROM(data, 'utf8') AS data
SELECT * FROM json_redpanda;

CREATE MATERIALIZED VIEW jsonified_bytes_m AS
SELECT CAST(data AS JSONB) AS data
FROM (
    SELECT CONVERT_FROM(data, 'utf8') AS data
    FROM json_redpanda
    WHERE key LIKE 'waterstream-fleet-demo/passengers_update/%'
);

CREATE MATERIALIZED VIEW passenger_company_m AS
    SELECT
        data->>'company' AS company,
        CAST(COALESCE(data->'passengers', '0') AS INTEGER) AS passengers
    FROM jsonified_bytes
--     WHERE data->>
;

CREATE MATERIALIZED VIEW passengers_by_company_m AS
SELECT A.company, SUM(A.passengers) AS passengers_sum
FROM (
  SELECT
      data->>'company' AS company,
      CAST(COALESCE(data->'passengers', '0') AS INTEGER) AS passengers
    FROM jsonified_bytes
) AS A
GROUP BY A.company;


CREATE MATERIALIZED VIEW taxis AS
SELECT T.company, T.passengers
FROM (
  SELECT 
    company AS company,
    passengers_sum AS passengers
  FROM passengers_by_company
) AS T
ORDER BY company ASC
LIMIT 10;
