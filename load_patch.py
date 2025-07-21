import httpx
import rdflib


def main():
    print("getting last patch id")
    response = httpx.post(
        "http://172.19.0.1:1066/$/rpc",
        json={"opid": "", "operation": "describe_datasource", "arg": {"name": "ds"}},
    )
    response.raise_for_status()
    id = response.json()["id"]
    response = httpx.post(
        "http://172.19.0.1:1066/$/rpc",
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
    response = httpx.post(
        url="http://172.19.0.1:1066/ds", headers=headers, content=patch
    )
    response.raise_for_status()
    json = response.json()
    print(json)
    print("patch submitted ok")

    print("checking the patch log")
    params = {"version": json["version"]}
    response = httpx.get("http://172.19.0.1:1066/ds", params=params)
    response.raise_for_status()
    print(response.content.decode())
    print("ok")

    params = {"query": "select * where { ?s ?p ?o } limit 10"}
    headers = {"Accept": "text/csv"}

    print("checking fuseki1")
    response = httpx.get("http://172.19.0.1:3030/ds", params=params, headers=headers)
    response.raise_for_status()
    print(response.content.decode())
    print("ok")

    print("checking fuseki2")
    response = httpx.get("http://172.19.0.1:3031/ds", params=params, headers=headers)
    response.raise_for_status()
    print(response.content.decode())
    print("ok")


if __name__ == "__main__":
    main()
