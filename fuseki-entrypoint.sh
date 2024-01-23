#!/bin/sh

exec \
  java \
  -cp "/opt/rdf-delta/rdf-delta-fuseki-server.jar:/opt/rdf-delta/compoundnaming.jar" \
  org.seaborne.delta.fuseki.cmd.DeltaFusekiServerCmd \
  --conf config.ttl