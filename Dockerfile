ARG DELTA_VERSION=2.0.0-SNAPSHOT
ARG DELTA_GIT_HASH=eb2bc11e5deeb68b7ac92d310948fc685b357692
ARG COMPOUND_NAMING_VERSION=0.1.1

#
# Builder stage
#
FROM maven:3.9.6-amazoncorretto-17 AS builder

RUN yum install -y \
        git

WORKDIR /tmp/rdf-delta

RUN git init && \
    git remote add origin https://github.com/afs/rdf-delta.git && \
    git fetch --depth 1 origin ${DELTA_GIT_HASH}:main && \
    git checkout main && \
    git clone --depth 100 https://github.com/afs/rdf-delta.git && \
    git reset --hard ${DELTA_GIT_HASH}

# RUN mvn -Drat.skip=true -B verify --file pom.xml
# Skip tests and skip license check, just package up the code
RUN mvn -Drat.skip=true -B package -DskipTests --file pom.xml

#
# Final stage
#
FROM amazoncorretto:17-alpine

ARG DELTA_VERSION
ARG COMPOUND_NAMING_VERSION

RUN apk update \
    && apk add --no-cache \
        bash \
        curl \
        libstdc++

WORKDIR /opt/rdf-delta

COPY entrypoint.sh .
COPY fuseki-entrypoint.sh .

COPY --from=builder /tmp/rdf-delta/rdf-delta-server/target/rdf-delta-server-${DELTA_VERSION}.jar rdf-delta-server.jar
COPY --from=builder /tmp/rdf-delta/rdf-delta-fuseki-server/target/rdf-delta-fuseki-server-${DELTA_VERSION}.jar rdf-delta-fuseki-server.jar

RUN wget -O /opt/rdf-delta/compoundnaming.jar https://github.com/Kurrawong/jena-compound-naming/releases/download/${COMPOUND_NAMING_VERSION}/compoundnaming-${COMPOUND_NAMING_VERSION}.jar

# Fuseki data directory for rdf delta
RUN mkdir -p /fuseki/delta-zones
# RDF Delta Patch server data directory
RUN mkdir -p /opt/rdf-delta/databases

# Run RDF Delta Patch server
# See /opt/rdf-delta/fuseki-entrypoint.sh to run Fuseki Main server
CMD [ "/bin/bash", "-c", "/opt/rdf-delta/entrypoint.sh" ]