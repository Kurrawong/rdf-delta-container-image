# latest as at 2025-11-06 (missing rocksdbjni jar)
# ARG DELTA_GIT_HASH=f352db5368cd1d37e26f7c3bd913e02fbd19b86f
#ARG DELTA_VERSION=2.0.0-SNAPSHOT
#ARG DELTA_GIT_HASH=3f8efaaf682ea14bc738dd610202956be4970716

#latest min-delta commit 2025-11-06
#ARG DELTA_GIT_HASH=376007ef5bb4662292509eb07c135a3d27b342ae
#ARG DELTA_VERSION=1.1.3-SNAPSHOT

#last commit before 1.1.3
ARG DELTA_GIT_HASH=bb2f9d2f5ea61fed37d5621ec3147dd01e9b0d5b
ARG DELTA_VERSION=2.0.0-SNAPSHOT

#
# Builder stage
#
FROM maven:3.9.11-amazoncorretto-25 AS builder

ARG DELTA_GIT_HASH

WORKDIR /tmp/rdf-delta

RUN yum install -y git unzip patch

RUN <<EOF
  # checkout the rdf-delta repo
  git init && \
      git remote add origin https://github.com/afs/rdf-delta.git && \
      git fetch --depth 1 origin ${DELTA_GIT_HASH}:main && \
      git checkout main && \
      git reset --hard ${DELTA_GIT_HASH}
EOF

# Apply a dependency patch for GeoSPARQL support
COPY patches/enable-geosparql.diff .
WORKDIR /tmp/rdf-delta/rdf-delta-fuseki-server
RUN patch --verbose --ignore-whitespace pom.xml < ../enable-geosparql.diff
WORKDIR /tmp/rdf-delta

# RUN mvn -Drat.skip=true -B verify --file pom.xml
# Skip tests and skip license check, just package up the code
RUN mvn -Drat.skip=true -B package -DskipTests --file pom.xml

  # unzip the distribution (has the cli commands in it)
RUN unzip /tmp/rdf-delta/rdf-delta-dist/target/*.zip

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
