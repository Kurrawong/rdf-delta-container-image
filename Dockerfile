ARG DELTA_GIT_HASH=0a44c60368c523361fd2ba1d929023e5f1987ee0
ARG DELTA_VERSION=1.1.3-SNAPSHOT
ARG JENA_VERSION=6.2.0-SNAPSHOT
ARG JENA_REPO=https://github.com/kurrawong/jena.git
ARG JENA_GIT_HASH=536b979b4fb1a852999588e71433bc838b14fa7e

#
# Builder stage
#
FROM maven:3.9.11-amazoncorretto-25 AS builder

ARG JENA_REPO
ARG JENA_GIT_HASH
ARG JENA_VERSION
ARG DELTA_GIT_HASH
ARG DELTA_VERSION


RUN yum install -y git unzip patch

# checkout the jena repo
WORKDIR /tmp/jena
RUN <<EOF
  git init
  git remote add origin ${JENA_REPO}
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

# Build RDF Delta
# RDF Delta normally selects the released Jena BOM. Override that property so
# every Jena dependency resolves to the fork built and installed above.
# Skip tests and skip license check, just package up the code.
RUN mvn \
    -Drat.skip=true \
    -DskipTests \
    -Dver.jena="${JENA_VERSION}" \
    -B package \
    --file pom.xml

# Fail the image build if dependency resolution or shading silently selects
# released Jena classes instead of the custom text implementation.
RUN <<EOF
  set -eu

  jar_path="/tmp/rdf-delta/rdf-delta-fuseki-server/target/rdf-delta-fuseki-server-${DELTA_VERSION}.jar"
  test -f "${jar_path}"

  for artifact in jena-fuseki-main jena-text jena-geosparql; do
    unzip -p "${jar_path}" \
      "META-INF/maven/org.apache.jena/${artifact}/pom.properties" \
      | grep -Fx "version=${JENA_VERSION}"
  done

  jar tf "${jar_path}" | grep -Fx \
    'org/apache/jena/query/text/assembler/ShaclTextIndexAssembler.class'

  jar tf "${jar_path}" | grep -Fx \
    'org/apache/jena/query/text/TextIndexRegistry.class'

  javap -private -classpath "${jar_path}" \
    org.apache.jena.query.text.assembler.TextDatasetAssembler \
    | grep -q 'openMultiIndex'
EOF

# Unzip the distribution (has the cli commands in it)
RUN unzip /tmp/rdf-delta/rdf-delta-dist/target/*.zip

#
# Final stage
#
FROM amazoncorretto:25-alpine3.21

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
