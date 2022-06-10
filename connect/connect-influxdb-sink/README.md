# InfluxDB Sink connector



## Objective

Quickly test [InfluxDB Sink](https://docs.confluent.io/current/connect/kafka-connect-influxdb/influx-db-sink-connector/index.html#quick-start) connector.




## How to run

Simply run:

```
$ ./influxdb-sink.sh
```

## Details of what the script is doing

Sending messages to topic orders

```bash
$ docker exec -i connect kafka-avro-console-producer --broker-list broker:9092 --property schema.registry.url=http://schema-registry:8081 --topic orders --property value.schema='{"type":"record","name":"myrecord","fields":[{"name":"measurement","type":"string"},{"name":"id","type":"int"},{"name":"product", "type": "string"}, {"name":"quantity", "type": "int"}, {"name":"price",
"type": "float"}]}' << EOF
{"measurement": "orders", "id": 999, "product": "foo", "quantity": 100, "price": 50}
EOF
```

Creating InfluxDB sink connector

```bash
$ curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class": "io.confluent.influxdb.InfluxDBSinkConnector",
                    "tasks.max": "1",
                    "influxdb.url": "http://influxdb:8086",
                    "topics": "orders"
          }' \
     http://localhost:8083/connectors/influxdb-sink/config | jq .
```

Verify data is in InfluxDB

```bash
curl -G 'http://localhost:8086/query?pretty=true' --data-urlencode "db=orders" --data-urlencode "q=SELECT \"price\" FROM \"orders\""
```

Results:

```json
{
    "results": [
        {
            "statement_id": 0,
            "series": [
                {
                    "name": "orders",
                    "columns": [
                        "time",
                        "price"
                    ],
                    "values": [
                        [
                            "2019-10-18T18:48:23.045Z",
                            50
                        ]
                    ]
                }
            ]
        }
    ]
}
```

N.B: Control Center is reachable at [http://127.0.0.1:9021](http://127.0.0.1:9021])
