# HDFS 2 Sink connector



## Objective

Quickly test [HDFS 2 Sink](https://docs.confluent.io/current/connect/kafka-connect-hdfs/index.html) connector.

Note: it also contains Hive integration

## How to run

Simply run:

```
$ ./hdfs2-sink.sh
```

or with Kerberos:

```
$ ./hdfs2-sink-kerberos.sh (without Hive support)
```

## Details of what the script is doing

The connector is created with:

```
$ curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class":"io.confluent.connect.hdfs.HdfsSinkConnector",
               "tasks.max":"1",
               "topics":"test_hdfs",
               "store.url":"hdfs://namenode:8020",
               "flush.size":"3",
               "hadoop.conf.dir":"/etc/hadoop/",
               "partitioner.class":"io.confluent.connect.hdfs.partitioner.FieldPartitioner",
               "partition.field.name":"f1",
               "rotate.interval.ms":"120000",
               "logs.dir":"/tmp",
               "hive.integration": "true",
               "hive.metastore.uris": "thrift://hive-metastore:9083",
               "hive.database": "testhive",
               "confluent.license": "",
               "confluent.topic.bootstrap.servers": "broker:9092",
               "confluent.topic.replication.factor": "1",
               "key.converter":"org.apache.kafka.connect.storage.StringConverter",
               "value.converter":"io.confluent.connect.avro.AvroConverter",
               "value.converter.schema.registry.url":"http://schema-registry:8081",
               "schema.compatibility":"BACKWARD"
          }' \
     http://localhost:8083/connectors/hdfs-sink/config | jq .
```

Messages are sent to `test_hdfs` topic using:

```
$ seq -f "{\"f1\": \"value%g\"}" 10 | docker exec -i connect kafka-avro-console-producer --broker-list broker:9092 --property schema.registry.url=http://schema-registry:8081 --topic test_hdfs --property value.schema='{"type":"record","name":"myrecord","fields":[{"name":"f1","type":"string"}]}'
```

After a few seconds, HDFS should contain files in /topics/test_hdfs:

```
$ docker exec hadoop bash -c "/usr/local/hadoop/bin/hdfs dfs -ls /topics/test_hdfs"

drwxr-xr-x   - root supergroup          0 2019-09-23 11:04 /topics/test_hdfs/f1=value1
drwxr-xr-x   - root supergroup          0 2019-09-23 11:04 /topics/test_hdfs/f1=value2
drwxr-xr-x   - root supergroup          0 2019-09-23 11:04 /topics/test_hdfs/f1=value3
drwxr-xr-x   - root supergroup          0 2019-09-23 11:04 /topics/test_hdfs/f1=value4
drwxr-xr-x   - root supergroup          0 2019-09-23 11:04 /topics/test_hdfs/f1=value5
drwxr-xr-x   - root supergroup          0 2019-09-23 11:04 /topics/test_hdfs/f1=value6
drwxr-xr-x   - root supergroup          0 2019-09-23 11:04 /topics/test_hdfs/f1=value7
drwxr-xr-x   - root supergroup          0 2019-09-23 11:04 /topics/test_hdfs/f1=value8
drwxr-xr-x   - root supergroup          0 2019-09-23 11:04 /topics/test_hdfs/f1=value9
```

Check data with beeline:

```
$ docker exec -i hive-server beeline << EOF
!connect jdbc:hive2://hive-server:10000/testhive
hive
hive
show create table test_hdfs;
select * from test_hdfs;
EOF
```

Results:

```
Beeline version 2.3.2 by Apache Hive
beeline> !connect jdbc:hive2://hive-server:10000/testhive
Connecting to jdbc:hive2://hive-server:10000/testhive
Enter username for jdbc:hive2://hive-server:10000/testhive: hive
Enter password for jdbc:hive2://hive-server:10000/testhive: ****
Connected to: Apache Hive (version 2.3.2)
Driver: Hive JDBC (version 2.3.2)
Transaction isolation: TRANSACTION_REPEATABLE_READ
0: jdbc:hive2://hive-server:10000/testhive> show create table test_hdfs;
+----------------------------------------------------+
|                   createtab_stmt                   |
+----------------------------------------------------+
| CREATE EXTERNAL TABLE `test_hdfs`(                 |
| )                                                  |
| PARTITIONED BY (                                   |
|   `f1` string COMMENT '')                          |
| ROW FORMAT SERDE                                   |
|   'org.apache.hadoop.hive.serde2.avro.AvroSerDe'   |
| STORED AS INPUTFORMAT                              |
|   'org.apache.hadoop.hive.ql.io.avro.AvroContainerInputFormat'  |
| OUTPUTFORMAT                                       |
|   'org.apache.hadoop.hive.ql.io.avro.AvroContainerOutputFormat' |
| LOCATION                                           |
|   'hdfs://namenode:8020/topics/test_hdfs'          |
| TBLPROPERTIES (                                    |
|   'avro.schema.literal'='{"type":"record","name":"ConnectDefault","namespace":"io.confluent.connect.avro","fields":[]}',  |
|   'transient_lastDdlTime'='1611071894')            |
+----------------------------------------------------+
15 rows selected (0.16 seconds)
0: jdbc:hive2://hive-server:10000/testhive> select * from test_hdfs;
+---------------+
| test_hdfs.f1  |
+---------------+
| value1        |
| value10       |
| value2        |
| value3        |
| value4        |
| value5        |
| value6        |
| value7        |
| value8        |
| value9        |
+---------------+
10 rows selected (1.919 seconds)
0: jdbc:hive2://hive-server:10000/testhive> Closing: 0: jdbc:hive2://hive-server:10000/testhive
```

N.B: Control Center is reachable at [http://127.0.0.1:9021](http://127.0.0.1:9021])
