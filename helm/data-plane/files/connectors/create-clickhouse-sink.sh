#!/bin/sh

NAMESPACE=${1:-neuraltrust}
echo "NAMESPACE: ${NAMESPACE}"

echo "Waiting for Kafka Connect to be ready..."
until curl -s http://kafka-connect-svc.${NAMESPACE}.svc.cluster.local:8083/connectors > /dev/null; do
  sleep 5
  echo "Waiting..."
done

echo "Creating ClickHouse traces_processed sink connector..."
curl -X POST http://kafka-connect-svc.${NAMESPACE}.svc.cluster.local:8083/connectors -H "Content-Type: application/json" -d '{
  "name": "clickhouse-traces-processed-sink",
  "config": {
    "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
    "tasks.max": "1",
    "topics": "traces_processed",
    "hostname": "'${CLICKHOUSE_HOST}'",
    "port": "'${CLICKHOUSE_PORT}'",
    "database": "'${CLICKHOUSE_DATABASE}'",
    "username": "'${CLICKHOUSE_USER}'",
    "password": "'${CLICKHOUSE_PASSWORD}'",
    "ssl": "false",
    "exactlyOnce": "false",
    "state.provider.class": "com.clickhouse.kafka.connect.sink.state.provider.FileStateProvider",
    "state.provider.working.dir": "/tmp/clickhouse-sink",
    "queue.max.wait.ms": "5000",
    "retry.max.count": "5",
    "errors.retry.timeout": "60",
    "errors.tolerance": "all",
    "errors.log.enable": "true",
    "errors.log.include.messages": "true",
    "table.name": "traces_processed",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "transforms": "flattenJson",
    "transforms.flattenJson.type": "org.apache.kafka.connect.transforms.Flatten$Value",
    "transforms.flattenJson.delimiter": "_"
  }
}' 

echo "Creating ClickHouse traces sink connector..."
curl -X POST http://kafka-connect-svc.${NAMESPACE}.svc.cluster.local:8083/connectors -H "Content-Type: application/json" -d '{
  "name": "clickhouse-traces-sink",
  "config": {
    "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
    "tasks.max": "1",
    "topics": "traces",
    "hostname": "'${CLICKHOUSE_HOST}'",
    "port": "'${CLICKHOUSE_PORT}'",
    "database": "'${CLICKHOUSE_DATABASE}'",
    "username": "'${CLICKHOUSE_USER}'",
    "password": "'${CLICKHOUSE_PASSWORD}'",
    "ssl": "false",
    "exactlyOnce": "false",
    "state.provider.class": "com.clickhouse.kafka.connect.sink.state.provider.FileStateProvider",
    "state.provider.working.dir": "/tmp/clickhouse-sink",
    "queue.max.wait.ms": "5000",
    "retry.max.count": "5",
    "errors.retry.timeout": "60",
    "errors.tolerance": "all",
    "errors.log.enable": "true",
    "errors.log.include.messages": "true",
    "table.name": "traces",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "transforms": "flattenJson",
    "transforms.flattenJson.type": "org.apache.kafka.connect.transforms.Flatten$Value",
    "transforms.flattenJson.delimiter": "_"
  }
}' 


echo "Creating ClickHouse firewall_metrics sink connector..."
curl -X POST http://kafka-connect-svc.${NAMESPACE}.svc.cluster.local:8083/connectors -H "Content-Type: application/json" -d '{
  "name": "clickhouse-firewall-metrics-sink",
  "config": {
    "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
    "tasks.max": "1",
    "topics": "firewall",
    "hostname": "'${CLICKHOUSE_HOST}'",
    "port": "'${CLICKHOUSE_PORT}'",
    "database": "'${CLICKHOUSE_DATABASE}'",
    "username": "'${CLICKHOUSE_USER}'",
    "password": "'${CLICKHOUSE_PASSWORD}'",
    "ssl": "false",
    "exactlyOnce": "false",
    "state.provider.class": "com.clickhouse.kafka.connect.sink.state.provider.FileStateProvider",
    "state.provider.working.dir": "/tmp/clickhouse-sink",
    "queue.max.wait.ms": "5000",
    "retry.max.count": "5",
    "errors.retry.timeout": "60",
    "errors.tolerance": "all",
    "errors.log.enable": "true",
    "errors.log.include.messages": "true",
    "table.name": "firewall",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "transforms": "flattenJson",
    "transforms.flattenJson.type": "org.apache.kafka.connect.transforms.Flatten$Value",
    "transforms.flattenJson.delimiter": "_"
  }
}' 

