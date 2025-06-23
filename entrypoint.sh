#!/bin/sh

exec \
  java \
  ${JAVA_OPTS} \
  --enable-native-access=ALL-UNNAMED \
  -jar /opt/rdf-delta/rdf-delta-server.jar \
  --store /opt/rdf-delta/databases