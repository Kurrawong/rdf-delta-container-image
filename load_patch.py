import json
import subprocess

import httpx
import rdflib


def get_docker_gateway() -> str:
    cmd = "docker inspect rdf-delta-container-image-delta-1"
    inspect_str = subprocess.check_output(cmd.split()).decode().strip()
    inpect_json = json.loads(inspect_str)
    gateway = inpect_json[0]["NetworkSettings"]["Networks"][
        "rdf-delta-container-image_delta"
    ]["Gateway"]
    return str(gateway)


def main():
    print("getting last patch id")
    gateway = get_docker_gateway()
    delta_client = httpx.Client(base_url=f"http://{gateway}:1066")
    fuseki1_client = httpx.Client(base_url=f"http://{gateway}:3030")
    fuseki2_client = httpx.Client(base_url=f"http://{gateway}:3031")
    response = delta_client.post(
        "/$/rpc",
        json={"opid": "", "operation": "describe_datasource", "arg": {"name": "ds"}},
    )
    response.raise_for_status()
    id = response.json()["id"]
    response = delta_client.post(
        "/$/rpc",
        json={"opid": "", "operation": "describe_log", "arg": {"datasource": id}},
    )
    header_prev = response.json()["latest"] or None

    print("parsing data from data.trig")
    ds = rdflib.Dataset(default_union=True)
    g = ds.graph()
    g.parse("data.trig")

    print("converting data to rdf patch")
    patch = ds.serialize(format="patch", operation="add", header_prev=header_prev)
    patch = patch.replace(f"H prev <{header_prev}>", f"H prev <uu{header_prev}> .")

    print("submitting patch log to rdf delta server")
    headers = {"Content-Type": "application/rdf-patch", "Accept": "application/json"}
    response = delta_client.post(url="/ds", headers=headers, content=patch)
    response.raise_for_status()
    json = response.json()
    print(json)
    print("patch submitted ok")

    print("checking the patch log")
    params = {"version": json["version"]}
    response = delta_client.get("/ds", params=params)
    response.raise_for_status()
    print(response.content.decode())
    print("ok")

    params = {"query": "select * where { ?s ?p ?o } limit 10"}
    headers = {"Accept": "text/csv"}

    print("checking fuseki1")
    response = fuseki1_client.get("/ds", params=params, headers=headers)
    response.raise_for_status()
    print(response.content.decode())
    print("ok")

    print("checking fuseki2")
    response = fuseki2_client.get("/ds", params=params, headers=headers)
    response.raise_for_status()
    print(response.content.decode())
    print("ok")


if __name__ == "__main__":
    main()
