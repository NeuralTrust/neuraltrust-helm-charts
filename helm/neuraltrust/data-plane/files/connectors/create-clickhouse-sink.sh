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

echo "Creating ClickHouse metrics sink connector..."
curl -X POST http://kafka-connect-svc.${NAMESPACE}.svc.cluster.local:8083/connectors -H "Content-Type: application/json" -d '{
  "name": "clickhouse-metrics-sink",
  "config": {
    "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
    "tasks.max": "1",
    "topics": "metrics",
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
    "table.name": "metrics",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false"
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

echo "Creating ClickHouse discover events sink connector..."
curl -X POST http://kafka-connect-svc.${NAMESPACE}.svc.cluster.local:8083/connectors -H "Content-Type: application/json" -d '{
  "name": "clickhouse-discover-events-sink",
  "config": {
    "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
    "tasks.max": "1",
    "topics": "discover_events",
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
    "table.name": "discover_events",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "transforms": "flattenJson",
    "transforms.flattenJson.type": "org.apache.kafka.connect.transforms.Flatten$Value",
    "transforms.flattenJson.delimiter": "_"
  }
}' 

echo "Creating ClickHouse agents events sink connector..."
curl -X POST http://kafka-connect-svc.${NAMESPACE}.svc.cluster.local:8083/connectors -H "Content-Type: application/json" -d '{
  "name": "clickhouse-agents-events-sink",
  "config": {
    "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
    "tasks.max": "1",
    "topics": "agent_traces",
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
    "table.name": "agent_traces",
    "value.converter.schemas.enable": "false",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.storage.StringConverter",
    "transforms": "hoist",
    "transforms.hoist.type": "org.apache.kafka.connect.transforms.HoistField$Value",
    "transforms.hoist.field": "raw_json"
  }
}' 

echo "Creating ClickHouse gpt_usage sink connector..."
curl -X POST http://kafka-connect-svc.${NAMESPACE}.svc.cluster.local:8083/connectors -H "Content-Type: application/json" -d '{
  "name": "clickhouse-gpt-usage-sink",
  "config": {
    "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
    "tasks.max": "1",
    "topics": "gpt_usage",
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
    "table.name": "gpt_usage",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "transforms": "flattenJson",
    "transforms.flattenJson.type": "org.apache.kafka.connect.transforms.Flatten$Value",
    "transforms.flattenJson.delimiter": "_",
    "primary.key.fields": "team_id,gizmo_id,author_user_id",
    "primary.key.mode": "record_value",
    "delete.enabled": "true"
  }
}' 