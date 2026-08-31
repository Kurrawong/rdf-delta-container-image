#!/bin/bash
# loadAndIndex.sh - Load RDF data into Fuseki TDB2 database and build text indexes
#
# This script performs the following steps:
#   1. Clean and recreate the Fuseki database directory
#   2. Load RDF data using the fuseki-lucene-shacl-loader in tdb2.xloader mode
#   3. Apply SPARQL update queries (magix.rq, magix2.rq) to transform the data
#   4. Build text indexes using the fuseki-lucene-shacl-loader in text mode
#   5. Copy the completed fusekia directory to fusekib
#
# Usage: ./loadAndIndex.sh

set -e # Exit immediately on error

# Get current user's UID and GID to ensure created files have correct ownership
USER_UID=$(id -u)
USER_GID=$(id -g)

# Timestamp function for consistent logging
TIMESTAMP() {
        date +"[%Y-%m-%d %H:%M:%S]"
}

# Logging function
echo_log() {
        echo "$(TIMESTAMP) $1"
}

echo_log "========================================"
echo_log "Starting loadAndIndex.sh"
echo_log "========================================"

# Step 1: Clean up and create database directory
echo_log "Step 1/5: Cleaning up and creating Fuseki database directories..."
rm -rf fusekia fusekib
mkdir -p fusekia/databases
echo_log "Step 1/5: Completed - Database directory ready at ./fusekia/databases"

# Step 2: Load RDF data using Docker container
echo_log "Step 2/5: Loading RDF data with fuseki-lucene-shacl-loader (tdb2.xloader mode)..."
docker run \
        --rm \
        --name loader \
        --user "$USER_UID:$USER_GID" \
        --volume "./config.ttl:/config.ttl" \
        --volume "./MAGIX:/rdf" \
        --volume "./fusekia/databases:/fuseki/databases" \
        --env "MODE=tdb2.xloader" \
        --env "NO_VALIDATION=true" \
        "fuseki-lucene-shacl-loader:6.2.0-SNAPSHOT"
echo_log "Step 2/5: Completed - RDF data loaded"

# Step 3: Apply SPARQL update queries
echo_log "Step 3/5: Applying SPARQL update queries..."
echo_log "  - Running magix.rq..."
tdb2.tdbupdate --loc=fusekia/databases/myds --update=queries/magix.rq
echo_log "  - Running magix2.rq..."
tdb2.tdbupdate --loc=fusekia/databases/myds --update=queries/magix2.rq
echo_log "Step 3/5: Completed - SPARQL updates applied"

# Step 4: Build text indexes
echo_log "Step 4/5: Building text indexes with fuseki-lucene-shacl-loader (text mode)..."
docker run \
        --rm \
        --name indexer \
        --user "$USER_UID:$USER_GID" \
        --volume "./config.ttl:/config.ttl" \
        --volume "./MAGIX:/rdf" \
        --volume "./fusekia/databases:/fuseki/databases" \
        --env "MODE=text" \
        --env "NO_VALIDATION=true" \
        "fuseki-lucene-shacl-loader:6.2.0-SNAPSHOT"
echo_log "Step 4/5: Completed - Text indexes built"

# Step 5: Copy the completed Fuseki directory
echo_log "Step 5/5: Copying fusekia to fusekib..."
cp -a fusekia fusekib
echo_log "Step 5/5: Completed - Fuseki directory copied to ./fusekib"

echo_log "========================================"
echo_log "loadAndIndex.sh completed successfully!"
echo_log "========================================"
