#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

if test -z "$(docker images -q container-registry.oracle.com/middleware/weblogic:12.2.1.3)"
then
     if [ ! -z "$CI" ]
     then
          # running with github actions
          if [ ! -f ../../secrets.properties ]
          then
               logerror "../../secrets.properties is not present!"
               exit 1
          fi
          source ../../secrets.properties > /dev/null 2>&1

          docker login container-registry.oracle.com -u $ORACLE_CONTAINER_REGISTRY_USERNAME -p "$ORACLE_CONTAINER_REGISTRY_PASSWORD"
          docker pull container-registry.oracle.com/middleware/weblogic:12.2.1.3
     else
          logerror "Image container-registry.oracle.com/middleware/weblogic:12.2.1.3 is not present. You must pull it from https://container-registry.oracle.com"
          exit 1
     fi
fi

# https://github.com/oracle/docker-images/tree/main/OracleWebLogic/samples/12212-domain-online-config
if test -z "$(docker images -q weblogic-jms:latest)"
then
     log "Building WebLogic JMS docker image..it can take a while..."
     OLDDIR=$PWD
     cd ${DIR}/docker-weblogic
     docker build --build-arg ADMIN_PASSWORD="welcome1" -t 1213-domain ./1213-domain
     docker build -t weblogic-jms:latest ./12212-domain-online-config -f ./12212-domain-online-config/Dockerfile
     cd ${OLDDIR}
fi

if [ ! -f ${DIR}/jms-sender/lib/wlthint3client.jar ]
then
     docker run weblogic-jms:latest cat /u01/oracle/wlserver/server/lib/wlthint3client.jar > ${DIR}/jms-sender/lib/wlthint3client.jar
fi

if [ ! -f ${DIR}/jms-sender/lib/weblogic.jar ]
then
     docker run weblogic-jms:latest cat /u01/oracle/wlserver/server/lib/weblogic.jar > ${DIR}/jms-sender/lib/weblogic.jar
fi

for component in jms-sender
do
     set +e
     log "🏗 Building jar for ${component}"
     docker run -i --rm -e KAFKA_CLIENT_TAG=$KAFKA_CLIENT_TAG -e TAG=$TAG_BASE -v "${DIR}/${component}":/usr/src/mymaven -v "$HOME/.m2":/root/.m2 -v "${DIR}/${component}/target:/usr/src/mymaven/target" -w /usr/src/mymaven maven:3.6.1-jdk-11 mvn -Dkafka.tag=$TAG -Dkafka.client.tag=$KAFKA_CLIENT_TAG package > /tmp/result.log 2>&1
     if [ $? != 0 ]
     then
          logerror "ERROR: failed to build java component $component"
          tail -500 /tmp/result.log
          exit 1
     fi
     set -e
done

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"

log "Creating JMS weblogic source connector"
curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class": "io.confluent.connect.weblogic.WeblogicSourceConnector",
               "kafka.topic": "from-weblogic-messages",
               "java.naming.factory.initial": "weblogic.jndi.WLInitialContextFactory",
               "jms.destination.name": "myJMSServer/mySystemModule!myJMSServer@MyDistributedQueue",
               "jms.destination.type": "QUEUE",
               "java.naming.provider.url": "t3://weblogic-jms:7001",
               "connection.factory.name": "myFactory",
               "java.naming.security.principal": "weblogic",
               "java.naming.security.credentials": "welcome1",
               "key.converter": "org.apache.kafka.connect.storage.StringConverter",
               "value.converter": "org.apache.kafka.connect.storage.StringConverter",
               "tasks.max" : "1",
               "batch.size": "1",
               "max.pending.messages": "1",
               "confluent.license": "",
               "confluent.topic.bootstrap.servers": "broker:9092",
               "confluent.topic.replication.factor": "1"
          }' \
     http://localhost:8083/connectors/weblogic-queue-source/config | jq .

sleep 5

log "Sending one message in JMS queue myQueue"
docker exec jms-sender bash -c 'java -cp "/tmp/weblogic.jar:/tmp/wlthint3client.jar:/jms-sender-1.0.0.jar" com.sample.jms.toolkit.JMSSender'

sleep 5

log "Verify we have received the data in from-weblogic-messages topic"
timeout 60 docker exec connect kafka-console-consumer -bootstrap-server broker:9092 --topic from-weblogic-messages --from-beginning --max-messages 1
