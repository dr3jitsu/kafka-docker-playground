# ActiveMQ Sink connector



## Objective

Quickly test [ActiveMQ Sink](https://docs.confluent.io/current/connect/kafka-connect-activemq/sink/index.html#kconnect-long-activemq-sink-connector) connector.

Using ActiveMQ Docker [image](https://hub.docker.com/r/rmohr/activemq/)




## How to run

Simply run:

```
$ ./active-mq-sink.sh
```

with SSL encryption + Mutual TLS authentication:

```
$ ./active-mq-sink-mtls.sh
```


## Details of what the script is doing

ActiveMQ UI is reachable at [http://127.0.0.1:8161](http://127.0.0.1:8161]) (`admin/admin`)

### Without SSL

Sending messages to topic `sink-messages`

```bash
$ docker exec -i broker kafka-console-producer --broker-list broker:9092 --topic sink-messages << EOF
This is my message
EOF
```

The connector is created with:

```bash
$ curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class": "io.confluent.connect.jms.ActiveMqSinkConnector",
               "topics": "sink-messages",
               "activemq.url": "tcp://activemq:61616",
               "activemq.username": "admin",
               "activemq.password": "admin",
               "jms.destination.name": "DEV.QUEUE.1",
               "jms.destination.type": "queue",
               "key.converter": "org.apache.kafka.connect.storage.StringConverter",
               "value.converter": "org.apache.kafka.connect.storage.StringConverter",
               "confluent.license": "",
               "confluent.topic.bootstrap.servers": "broker:9092",
               "confluent.topic.replication.factor": "1"
          }' \
     http://localhost:8083/connectors/active-mq-sink/config | jq .
```

Get messages from DEV.QUEUE.1 JMS queue:

```bash
$ curl -XGET -u admin:admin -d "body=message" http://localhost:8161/api/message/DEV.QUEUE.1?type=queue
```

We get:

```
This is my message
```

### With SSL encryption + Mutual TLS auth

Active QM is set with (file `/opt/apache-activemq-5.15.9/conf/activemq.xml`):

```xml
<transportConnector name="ssl" uri="ssl://0.0.0.0:61617?trace=true&amp;needClientAuth=true" />
```

and

```xml
    <sslContext>
        <sslContext keyStore="file:/tmp/kafka.activemq.keystore.jks" keyStorePassword="confluent" trustStore="file:/tmp/kafka.activemq.truststore.jks" trustStorePassword="confluent" />
    </sslContext>
```

Connect is set with:

```yml
      KAFKA_OPTS: -Djavax.net.ssl.trustStore=/tmp/truststore.jks
                  -Djavax.net.ssl.trustStorePassword=confluent
                  -Djavax.net.ssl.keyStore=/tmp/keystore.jks
                  -Djavax.net.ssl.keyStorePassword=confluent
```

The connector is created with:

```bash
$ curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class": "io.confluent.connect.activemq.ActiveMQSourceConnector",
               "kafka.topic": "MyKafkaTopicName",
               "activemq.url": "ssl://activemq:61617",
               "jms.destination.name": "DEV.QUEUE.1",
               "jms.destination.type": "queue",
               "confluent.license": "",
               "confluent.topic.bootstrap.servers": "broker:9092",
               "confluent.topic.replication.factor": "1"
          }' \
     http://localhost:8083/connectors/active-mq-source-mtls/config | jq .
```

N.B: Control Center is reachable at [http://127.0.0.1:9021](http://127.0.0.1:9021])
