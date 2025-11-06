# latest as at 2025-11-06 (missing rocksdbjni jar)
# ARG DELTA_VERSION=1.1.3-SNAPSHOT
# ARG DELTA_GIT_HASH=f352db5368cd1d37e26f7c3bd913e02fbd19b86f

ARG DELTA_VERSION=2.0.0-SNAPSHOT
ARG DELTA_GIT_HASH=3f8efaaf682ea14bc738dd610202956be4970716

#
# Builder stage
#
FROM maven:3.9.11-amazoncorretto-25 AS builder

ARG DELTA_GIT_HASH

WORKDIR /tmp/rdf-delta 

RUN yum install -y git unzip 

RUN <<EOF
  # checkout the rdf-delta repo
  git clone --no-checkout --depth 1 https://github.com/afs/rdf-delta.git .
  git fetch --depth 1 origin ${DELTA_GIT_HASH}
  git checkout ${DELTA_GIT_HASH}

  # RUN mvn -Drat.skip=true -B verify --file pom.xml
  # Skip tests and skip license check, just package up the code
  mvn -Drat.skip=true -B package -DskipTests --file pom.xml

  # unzip the distribution (has the cli commands in it)
  unzip /tmp/rdf-delta/rdf-delta-dist/target/*.zip 
EOF

#
# Final stage
#
FROM amazoncorretto:21-alpine

ARG DELTA_VERSION

RUN <<EOF
  apk update 
  apk add --no-cache bash curl libstdc++ 
EOF

WORKDIR /opt/rdf-delta

COPY config.ttl /opt/rdf-delta/config.ttl
COPY entrypoint.sh .
COPY fuseki-entrypoint.sh .

RUN mkdir cli 

COPY --from=builder /tmp/rdf-delta/rdf-delta-server/target/rdf-delta-server-${DELTA_VERSION}.jar rdf-delta-server.jar
COPY --from=builder /tmp/rdf-delta/rdf-delta-fuseki-server/target/rdf-delta-fuseki-server-${DELTA_VERSION}.jar rdf-delta-fuseki-server.jar
COPY --from=builder /tmp/rdf-delta/rdf-delta-${DELTA_VERSION} cli

# Fuseki data directory for rdf delta
RUN mkdir -p /fuseki/delta-zones 

# RDF Delta Patch server data directory
RUN mkdir -p /opt/rdf-delta/databases 

# Run RDF Delta Patch server
# See /opt/rdf-delta/fuseki-entrypoint.sh to run Fuseki Main server
CMD [ "/bin/bash", "-c", "/opt/rdf-delta/entrypoint.sh" ]
