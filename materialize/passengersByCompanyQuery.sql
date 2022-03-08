CREATE DATABASE metabase;

SET DATABASE=metabase;

CREATE SOURCE json_redpanda FROM KAFKA BROKER 'redpanda:9092' TOPIC 'mqtt_messages' KEY FORMAT TEXT VALUE FORMAT BYTES INCLUDE KEY;

CREATE VIEW jsonified_bytes AS
SELECT CAST(data AS JSONB) AS data
FROM (
    SELECT CONVERT_FROM(data, 'utf8') AS data
    FROM json_redpanda
    WHERE key LIKE 'waterstream-fleet-demo/passengers_update/%'
);

CREATE VIEW passengers_by_company AS
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
