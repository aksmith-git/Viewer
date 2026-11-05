import sys
sys.path.insert(0, "scripts")
from asc import call
APP = sys.argv[1]

# price: free, USA as base territory
points = call("GET", f"/v1/apps/{APP}/appPricePoints", params={"filter[territory]": "USA", "limit": 200})["data"]
free = next(p for p in points if float(p["attributes"]["customerPrice"]) == 0)
call("POST", "/v1/appPriceSchedules", {
    "data": {"type": "appPriceSchedules", "relationships": {
        "app": {"data": {"type": "apps", "id": APP}},
        "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
        "manualPrices": {"data": [{"type": "appPrices", "id": "${p1}"}]}}},
    "included": [{"type": "appPrices", "id": "${p1}", "attributes": {"startDate": None},
                  "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})
print("price: free")

# availability: every territory, plus new ones automatically
r = call("GET", f"/v1/apps/{APP}/appAvailabilityV2", ok=(200, 404))
if r.get("data"):
    print("availability already set")
else:
    territories, url = [], "/v1/territories"
    params = {"limit": 200}
    while url:
        page = call("GET", url, params=params)
        territories += [t["id"] for t in page["data"]]
        url, params = page.get("links", {}).get("next"), None
    included = [{"type": "territoryAvailabilities", "id": f"${{t{i}}}", "attributes": {"available": True},
                 "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for i, t in enumerate(territories)]
    call("POST", "/v2/appAvailabilities", {
        "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True}, "relationships": {
            "app": {"data": {"type": "apps", "id": APP}},
            "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": x["id"]} for x in included]}}},
        "included": included})
    print(f"availability: {len(territories)} territories")
