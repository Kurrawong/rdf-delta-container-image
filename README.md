# RDF Delta Container Image

## Usage

This repository builds and publishes the `rdf-delta` container image that has
the RDF Delta server jar file and the delta patch log enabled Fuseki server jar.

RDF delta is an RDF patch based server that enables high availability scenarios for
Fuseki. See the [documentation](https://afs.github.io/rdf-delta/)
and the [rdf-delta GitHub repository](https://github.com/afs/rdf-delta)
for more information.

Pre-built container images are available at
https://github.com/Kurrawong/rdf-delta-container-image/pkgs/container/rdf-delta.

See the [compose.yml](compose.yml) for general container setup.

## Quickstart

Use [task](https://taskfile.dev) to run the commands in [Taskfile.yml](Taskfile.yml).

```shell
# Start the services using docker compose
task up

# Load the example data to RDF Delta server
task load
```

You will now have an RDF Delta server with the initial data loaded and two
Fuseki servers synced to it.

## RDF Delta Server HTTP API

The HTTP API is documented at
[rdf-patch-logs.html](https://afs.github.io/rdf-delta/rdf-patch-logs.html).

| Operation                          | Effect        |
| ---------------------------------- | ------------- |
| POST http://.../{shortName}/       | Append to log |
| GET http://.../{shortName}/{id}    | Get a patch   |
| GET http://.../{shortName}/version | Get a patch   |

### Creating Patch Logs

When creating new patch logs, a downstream client will always need to ask
the RDF Delta Server for the latest patch id in order to create and send a
valid patch log.

You can use the [rdf-delta-python](https://github.com/Kurrawong/rdf-delta-python)
`DeltaClient` class and its `describe_log` method to retrieve the version information.

The [load_patch.py](./load_patch.py) script shows how to get / submit patches using
`rdflib` and `httpx`

Or you can also use any other http client to interact with the server.

For an example with `curl`

```bash
# get the datasource id
payload="
  {
    'opid': '',
    'operation': 'describe_datasource',
    'arg': {
      'name': 'ds'
    }
  }
"
response=$(curl -s -X POST http://172.19.0.1:1066/$/rpc --data "$payload")
echo "$response"
datasource_id=$(echo "$response" | jq -r '.id')

# get the latest patch log version
payload="
  {
    'opid': '',
    'operation': 'describe_log',
    'arg': {
      'datasource': '$datasource_id'
    }
  }
"
response=$(curl -s -X POST http://172.19.0.1:1066/$/rpc --data "$payload")
echo "$response"
latest=$(echo "$response" | jq -r '.latest')

# send a new patch
patch="H id <uuid:$(uuidgen)> ."
if [ "$latest" ]; then
  patch+="
H prev <uu$latest> ."
fi
patch+="
TX .
A <a> <b> <c> .
TC .
"
echo "$patch"
curl -s -X POST http://172.19.0.1:1066/ds \
  --data "$patch" \
  -H "Content-Type: application/rdf-patch"
```

