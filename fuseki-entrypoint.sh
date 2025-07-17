#!/bin/sh

exec \
  java \
  ${JAVA_OPTS} \
  --enable-native-access=ALL-UNNAMED \
  --add-modules jdk.incubator.vector \
  -cp "/opt/rdf-delta/rdf-delta-fuseki-server.jar" \
  org.seaborne.delta.fuseki.cmd.DeltaFusekiServerCmd \
  --conf config.ttl
