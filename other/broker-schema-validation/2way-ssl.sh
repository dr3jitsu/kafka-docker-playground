#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

if ! version_gt $TAG_BASE "5.3.99"; then
    logwarn "WARN: Broker Validation is available since CP 5.4 only"
    exit 111
fi

${DIR}/../../environment/2way-ssl/start.sh "${PWD}/docker-compose.2way-ssl.yml"

log "Create topic topic-validation"
docker exec broker kafka-topics --bootstrap-server broker:9092 --create --topic topic-validation --partitions 1 --replication-factor 2 --command-config /etc/kafka/secrets/client_without_interceptors_2way_ssl.config --config confluent.key.schema.validation=true --config confluent.value.schema.validation=true

log "Describe topic"
docker exec broker kafka-topics \
   --describe \
   --topic topic-validation \
   --bootstrap-server broker:9092 \
   --command-config /etc/kafka/secrets/client_without_interceptors_2way_ssl.config

log "Register schema"
curl -X POST \
   -H "Content-Type: application/vnd.schemaregistry.v1+json" \
   --cert ../../environment/2way-ssl/security/connect.certificate.pem --key ../../environment/2way-ssl/security/connect.key --tlsv1.2 --cacert ../../environment/2way-ssl/security/snakeoil-ca-1.crt \
   --data '{ "schema": "[ { \"type\":\"record\", \"name\":\"user\", \"fields\": [ {\"name\":\"userid\",\"type\":\"long\"}, {\"name\":\"username\",\"type\":\"string\"} ]} ]" }' \
   https://localhost:8081/subjects/topic-validation-value/versions

log "Sending a non-Avro record, it should fail"
docker exec -i connect kafka-console-producer \
     --topic topic-validation \
     --broker-list broker:9092 \
     --producer.config /etc/kafka/secrets/client_without_interceptors_2way_ssl.config << EOF
{"userid":1,"username":"RODRIGUEZ"}
EOF

log "Sending a Avro record, it should work"
docker exec -i connect kafka-avro-console-producer \
     --topic topic-validation \
     --broker-list broker:9092 \
     --property schema.registry.url=https://schema-registry:8081 \
     --property schema.registry.ssl.truststore.location=/etc/kafka/secrets/kafka.client.truststore.jks \
     --property schema.registry.ssl.truststore.password=confluent \
     --property schema.registry.ssl.keystore.location=/etc/kafka/secrets/kafka.client.keystore.jks \
     --property schema.registry.ssl.keystore.password=confluent \
     --property value.schema='{"type":"record","name":"user","fields":[{"name":"userid","type":"long"},{"name":"username","type":"string"}]}' \
     --producer.config /etc/kafka/secrets/client_without_interceptors_2way_ssl.config << EOF
{"userid":1,"username":"RODRIGUEZ"}
EOF

log "Verify we have the record"
docker exec connect kafka-avro-console-consumer -bootstrap-server broker:9092 --topic topic-validation --from-beginning --max-messages 1 --property schema.registry.url=https://schema-registry:8081 --property schema.registry.ssl.truststore.location=/etc/kafka/secrets/kafka.client.truststore.jks --property schema.registry.ssl.truststore.password=confluent --property schema.registry.ssl.keystore.location=/etc/kafka/secrets/kafka.client.keystore.jks --property schema.registry.ssl.keystore.password=confluent --consumer.config /etc/kafka/secrets/client_without_interceptors_2way_ssl.config