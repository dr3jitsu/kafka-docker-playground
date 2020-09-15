#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

verify_memory
verify_installed "docker-compose"

DOCKER_COMPOSE_FILE_OVERRIDE=$1
if [ -f "${DOCKER_COMPOSE_FILE_OVERRIDE}" ]
then
  docker-compose -f ../../environment/plaintext/docker-compose.yml -f ../../ksqldb/environment/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} build
  docker-compose -f ../../environment/plaintext/docker-compose.yml -f ../../ksqldb/environment/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} down -v
  docker-compose -f ../../environment/plaintext/docker-compose.yml -f ../../ksqldb/environment/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} up -d
else
  docker-compose -f ../../environment/plaintext/docker-compose.yml -f ../../ksqldb/environment/docker-compose.yml build
  docker-compose -f ../../environment/plaintext/docker-compose.yml -f ../../ksqldb/environment/docker-compose.yml down -v
  docker-compose -f ../../environment/plaintext/docker-compose.yml -f ../../ksqldb/environment/docker-compose.yml up -d
fi

if [ "$#" -ne 0 ]
then
    shift
fi
../../scripts/wait-for-connect-and-controlcenter.sh $@

log "Login with CLI using"
log "docker exec -it ksqldb-cli ksql http://ksqldb-server:8088"