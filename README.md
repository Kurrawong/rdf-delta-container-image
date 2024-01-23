# RDF Delta Container Image

## Usage

Pre-built container images are available at https://github.com/Kurrawong/rdf-delta-container-image/pkgs/container/rdf-delta.

See [docker-compose.yml](docker-compose.yml) for general container setup.

This repository builds and publishes the `rdf-delta` image with both the RDF Delta server and Fuseki with delta patch log sync enabled.

It also includes the Jena [Compound Naming functions](https://github.com/Kurrawong/jena-compound-naming).

## Quickstart

Run the following Taskfile commands or refer to the underlying docker compose commands in [Taskfile.yml](Taskfile.yml).

```shell
# Start the services using docker compose
task up

# Load example data to RDF Delta server
task load
```

You will now have an RDF Delta server with the initial data loaded and two Fuseki servers synced to it.

You will be able to send SPARQL queries to both Fuseki servers on `/ds`.

> Send a query using the compound naming function `getComponents`.

```sparql
SELECT *
WHERE {
    BIND(<https://linked.data.gov.au/dataset/qld-addr/addr-obj-1837741> AS ?iri)
    ?iri <java:ai.kurrawong.jena.compoundnaming.getComponents> (?componentType ?componentValue ?componentId) .
}
limit 10
```

You will get the following result:

<details>
    <summary>View result</summary>

```
{ "head": {
    "vars": [ "iri" , "componentType" , "componentValue" , "componentId" ]
  } ,
  "results": {
    "bindings": [
      {
        "iri": { "type": "uri" , "value": "https://linked.data.gov.au/dataset/qld-addr/addr-obj-1837741" } ,
        "componentType": { "type": "uri" , "value": "https://w3id.org/profile/anz-address/AnzAddressComponentTypes/numberFirst" } ,
        "componentValue": { "type": "literal" , "value": "2342" } ,
        "componentId": { "type": "literal" , "value": "_:59d38bb385f7a08fa55521964314431f" }
      } ,
      {
        "iri": { "type": "uri" , "value": "https://linked.data.gov.au/dataset/qld-addr/addr-obj-1837741" } ,
        "componentType": { "type": "uri" , "value": "https://w3id.org/profile/anz-address/AnzAddressComponentTypes/locality" } ,
        "componentValue": { "type": "literal" , "value": "MERMAID BEACH" } ,
        "componentId": { "type": "literal" , "value": "<https://linked.data.gov.au/dataset/qld-addr/locality-MERMAID-BEACH>" }
      } ,
      {
        "iri": { "type": "uri" , "value": "https://linked.data.gov.au/dataset/qld-addr/addr-obj-1837741" } ,
        "componentType": { "type": "uri" , "value": "https://w3id.org/profile/anz-address/AnzAddressComponentTypes/numberLast" } ,
        "componentValue": { "type": "literal" , "value": "2358" } ,
        "componentId": { "type": "literal" , "value": "_:c7c27dea4b78b405697499bb607b6d98" }
      } ,
      {
        "iri": { "type": "uri" , "value": "https://linked.data.gov.au/dataset/qld-addr/addr-obj-1837741" } ,
        "componentType": { "type": "uri" , "value": "https://w3id.org/profile/anz-address/AnzAddressComponentTypes/flatTypeCode" } ,
        "componentValue": { "type": "literal" , "value": "U" } ,
        "componentId": { "type": "literal" , "value": "<https://example.com/flatTypeCode/U>" }
      } ,
      {
        "iri": { "type": "uri" , "value": "https://linked.data.gov.au/dataset/qld-addr/addr-obj-1837741" } ,
        "componentType": { "type": "uri" , "value": "https://w3id.org/profile/anz-address/AnzAddressComponentTypes/flatNumber" } ,
        "componentValue": { "type": "literal" , "value": "14" } ,
        "componentId": { "type": "literal" , "value": "_:7171660f119972efcc2ac158667912c1" }
      } ,
      {
        "iri": { "type": "uri" , "value": "https://linked.data.gov.au/dataset/qld-addr/addr-obj-1837741" } ,
        "componentType": { "type": "uri" , "value": "https://linked.data.gov.au/def/roads/ct/RoadType" } ,
        "componentValue": { "type": "literal" , "value": "HWY (Y)" } ,
        "componentId": { "type": "literal" , "value": "_:d431e7556a44be11a59e6162f8b017d1" }
      } ,
      {
        "iri": { "type": "uri" , "value": "https://linked.data.gov.au/dataset/qld-addr/addr-obj-1837741" } ,
        "componentType": { "type": "uri" , "value": "https://w3id.org/profile/anz-address/AnzAddressComponentTypes/levelTypeCode" } ,
        "componentValue": { "type": "literal" , "value": "G" } ,
        "componentId": { "type": "literal" , "value": "<https://linked.data.gov.au/dataset/gnaf/code/levelType/G>" }
      } ,
      {
        "iri": { "type": "uri" , "value": "https://linked.data.gov.au/dataset/qld-addr/addr-obj-1837741" } ,
        "componentType": { "type": "uri" , "value": "https://linked.data.gov.au/def/roads/ct/RoadName" } ,
        "componentValue": { "type": "literal" , "value": "Gold Coast" } ,
        "componentId": { "type": "literal" , "value": "_:1e00ba69154e028bd57c4d752bb67de0" }
      }
    ]
  }
}

```

</details>

## RDF Delta Server HTTP API

The HTTP API is documented at [rdf-patch-logs.html](https://afs.github.io/rdf-delta/rdf-patch-logs.html).

```
http://.../{shortName}/
          /{shortName}/init -- "version 0" but dataset vs patch.
          /{shortName}/current --  "highest version"
          /{shortName}/patch/{version} -- all digits.
          /{shortName}/patch/{id} -- A UUID string which has "-"
```

### Creating Patch Logs

When creating new patch logs, a downstream client will always need to ask the RDF Delta Server for the latest patch id in order to create and send a valid patch log. According to the documentation, a request to `/ds/current` should provide that, but instead we are getting an unexpected response. Hopefully, we get a reply on [GitHub](https://github.com/afs/rdf-delta/discussions/270) on how to formulate the request correctly.

The current workaround to get the latest patch id is to send a bogus `POST` request by sending an empty patch log with a generated version 4 UUID.

```turtle
H id <uuid:a563c698-f911-41b1-9c06-3cc7ce13bbda> .
```

The server will respond with a `400` with the following body in JSON.

```json
{
  "error": "patch-conflict",
  "log_info": {
    "id": "id:85eec0a0-3c89-4669-ad98-ab002b30d649",
    "name": "ds",
    "uri": "delta:ds",
    "min_version": 1,
    "max_version": 1,
    "latest": "id:8251fdfa-46a1-427b-871c-0659a2da439c"
  }
}
```

The properties of interest within `log_info`:

- `min_version` - the first patch log _version_
- `max_version` - the latest patch log _version_
- `latest` - the latest patch log _id_

Now that the _id_ is known, we can construct a valid RDF patch and send a `POST` request to the RDF Delta Server at `/ds/`.

> Creating new patch log. Ensure a new UUID is generated for the id.

```
H id <uuid:0d82d6ab-823e-4c38-b96c-0765c2230563> .
H prev <uuid:8251fdfa-46a1-427b-871c-0659a2da439c> .
TX .
A <http://example/SubClass> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Class> .
TC .
```

### Retrieving Patch Logs

Patch logs can be retrieved by providing either the _version_ or the _id_ as a path parameter to `/ds/...`

With the new patch log created above, we can retrieve it by making one of the following requests:

- `/ds/2`
- `/ds/0d82d6ab-823e-4c38-b96c-0765c2230563`
