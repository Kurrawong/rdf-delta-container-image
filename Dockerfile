ARG DELTA_GIT_HASH=f352db5368cd1d37e26f7c3bd913e02fbd19b86f
ARG DELTA_VERSION=1.1.3-SNAPSHOT
ARG JENA_GIT_HASH=f6aa0ea7be9a59e525875b7a89e6c72fff201875

#
# Builder stage
#
FROM maven:3.9.11-amazoncorretto-25 AS builder

ARG JENA_GIT_HASH
ARG DELTA_GIT_HASH


RUN yum install -y git unzip patch

# checkout the jena repo
WORKDIR /tmp/jena
RUN <<EOF
  git init
  git remote add origin https://github.com/apache/jena.git
  git fetch --depth 1 origin ${JENA_GIT_HASH}
  git checkout ${JENA_GIT_HASH}
EOF

# build jena at the designated commit
RUN mvn clean install -Drat.skip=true -DskipTests

# checkout the rdf-delta repo
WORKDIR /tmp/rdf-delta
RUN <<EOF
  git init
  git remote add origin https://github.com/afs/rdf-delta.git
  git fetch --depth 1 origin ${DELTA_GIT_HASH}
  git checkout ${DELTA_GIT_HASH}
EOF

# Apply a dependency patch for GeoSPARQL support
COPY patches/enable-geosparql.diff .
WORKDIR /tmp/rdf-delta/rdf-delta-fuseki-server
RUN patch --verbose --ignore-whitespace pom.xml < ../enable-geosparql.diff
WORKDIR /tmp/rdf-delta

# Apply a patch for issue in rocksdb 10.4.2 (explicitly requires native binaries for linux64-musl)
WORKDIR /tmp/rdf-delta
COPY patches/rocksdb.diff .
RUN patch -p1 < rocksdb.diff

# Apply a patch to use the local version of jena we just built
WORKDIR /tmp/rdf-delta
COPY patches/local-jena.diff .
RUN patch -p1 < local-jena.diff

# Build RDF Delta
# Skip tests and skip license check, just package up the code
RUN mvn -Drat.skip=true -B package -DskipTests --file pom.xml

# Unzip the distribution (has the cli commands in it)
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
