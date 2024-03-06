#
# Downloader stage
#
FROM alpine:3 AS downloader

ARG COMPOUND_NAMING_VERSION=0.4.1

RUN mkdir -p /opt/fuseki
RUN wget -O /opt/fuseki/compoundnaming.jar https://github.com/Kurrawong/jena-compound-naming/releases/download/${COMPOUND_NAMING_VERSION}/compoundnaming-${COMPOUND_NAMING_VERSION}.jar

#
# Final stage
#
FROM ghcr.io/zazuko/fuseki-geosparql:v3.0.0

COPY ./fuseki-geosparql-entrypoint.sh /opt/fuseki/entrypoint.sh


COPY --from=downloader /opt/fuseki/compoundnaming.jar /opt/fuseki/compoundnaming.jar