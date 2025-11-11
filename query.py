"""query.py

Submit some test queries to the fuseki servers

"""

from itertools import product

import httpx

fuseki1 = "http://localhost:3030/ds"
fuseki2 = "http://localhost:3031/ds"

basic_query = """
PREFIX geo: <http://www.opengis.net/ont/geosparql#>
SELECT *
WHERE {
  ?s a geo:Feature .
  ?s ?p ?o .
}
LIMIT 5
"""

geosparql_query = """
PREFIX addr:    <https://linked.data.gov.au/def/addr/>
PREFIX geo: <http://www.opengis.net/ont/geosparql#>
PREFIX geof: <http://www.opengis.net/def/function/geosparql/>

SELECT DISTINCT ?address
WHERE {
  ?address a addr:Address .
  <https://example.org/australia> geo:sfContains ?address .
}
LIMIT 5
"""

text_query = """
PREFIX text: <http://jena.apache.org/text#>

SELECT *
WHERE {
    ?uri text:query "queensland" .
}
LIMIT 5
"""

text_and_geosparql_query = """
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX geo: <http://www.opengis.net/ont/geosparql#>
PREFIX geof: <http://www.opengis.net/def/function/geosparql/>
PREFIX text: <http://jena.apache.org/text#>

SELECT DISTINCT ?address ?literal
WHERE {
  BIND("POLYGON ((152.685242 -27.161808, 152.698975 -27.829361, 153.492737 -27.829361, 153.435059 -27.178912, 152.685242 -27.161808))"^^geo:wktLiteral AS ?polygon)
  ?address geo:hasGeometry / geo:asWKT ?point ;
           rdfs:label ?addressLabel .
  FILTER(geof:sfWithin(?point, ?polygon))
  (?address ?score ?literal) text:query ( "Drive" "highlight:" ) .
}
"""

queries = (basic_query, geosparql_query, text_query, text_and_geosparql_query)
servers = (fuseki1, fuseki2)

combinations = product(servers, queries)

headers = {"Content-Type": "application/sparql-query", "Accept": "text/csv"}

for server, query in combinations:
    client = httpx.Client()
    response = client.post(server, content=query, headers=headers)
    response.raise_for_status()
    print(response.content.decode())
