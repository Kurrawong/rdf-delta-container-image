ARG DELTA_VERSION=2.0.0-SNAPSHOT
ARG DELTA_GIT_HASH=ae3c6c8d94595c8285a01e6ca4f8ba3f3ac58c5d
ARG COMPOUND_NAMING_VERSION=0.6.0

#
# Builder stage
#
FROM maven:3.9.6-amazoncorretto-21 AS builder

RUN yum install -y \
        git \
        unzip

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

RUN unzip /tmp/rdf-delta/rdf-delta-dist/target/*.zip

#
# Final stage
#
FROM amazoncorretto:21-alpine

ARG DELTA_VERSION
ARG COMPOUND_NAMING_VERSION

RUN apk update \
    && apk add --no-cache \
        bash \
        curl \
        libstdc++

WORKDIR /opt/rdf-delta

COPY config.ttl /opt/rdf-delta/config.ttl
COPY entrypoint.sh .
COPY fuseki-entrypoint.sh .
RUN mkdir cli

COPY --from=builder /tmp/rdf-delta/rdf-delta-server/target/rdf-delta-server-${DELTA_VERSION}.jar rdf-delta-server.jar
COPY --from=builder /tmp/rdf-delta/rdf-delta-fuseki-server/target/rdf-delta-fuseki-server-${DELTA_VERSION}.jar rdf-delta-fuseki-server.jar
COPY --from=builder /tmp/rdf-delta/rdf-delta-${DELTA_VERSION} cli

RUN wget -O /opt/rdf-delta/compoundnaming.jar https://github.com/Kurrawong/jena-compound-naming/releases/download/${COMPOUND_NAMING_VERSION}/compoundnaming-${COMPOUND_NAMING_VERSION}.jar

# Fuseki data directory for rdf delta
RUN mkdir -p /fuseki/delta-zones
# RDF Delta Patch server data directory
RUN mkdir -p /opt/rdf-delta/databases

# Run RDF Delta Patch server
# See /opt/rdf-delta/fuseki-entrypoint.sh to run Fuseki Main server
CMD [ "/bin/bash", "-c", "/opt/rdf-delta/entrypoint.sh" ]
