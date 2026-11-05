import sys, time
sys.path.insert(0, "scripts")
from asc import call
APP, VERSION = sys.argv[1], sys.argv[2]
loc = call("GET", f"/v1/appStoreVersions/{VERSION}/appStoreVersionLocalizations")["data"][0]
sets = call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
for i in range(120):                     # up to 30 minutes
    states = []
    for s in sets:
        states += [x["attributes"]["assetDeliveryState"]["state"] for x in call("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots")["data"]]
    summary = {s: states.count(s) for s in set(states)}
    if "UPLOAD_COMPLETE" not in summary: break
    time.sleep(15)
print("screenshots:", summary, flush=True)
if set(summary) != {"COMPLETE"}: raise SystemExit("screenshots not all processed")
subs = call("GET", "/v1/reviewSubmissions", params={"filter[app]": APP, "filter[state]": "READY_FOR_REVIEW"})["data"]
sub = subs[0] if subs else call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
    "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]
if not call("GET", f"/v1/reviewSubmissions/{sub['id']}/items")["data"]:
    call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
        "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                          "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VERSION}}}}})
done = call("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
print("submission:", done["data"]["attributes"]["state"])
v = call("GET", f"/v1/appStoreVersions/{VERSION}")["data"]["attributes"]
print("version:", v.get("appStoreState"), v.get("appVersionState"))
