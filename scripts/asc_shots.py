import os, sys, time, requests
sys.path.insert(0, "scripts")
from asc import call, md5
VERSION = sys.argv[1]
SETS = {"APP_IPHONE_67": "appstore/screenshots/iphone-6.9", "APP_IPAD_PRO_3GEN_129": "appstore/screenshots/ipad-13"}

loc = call("GET", f"/v1/appStoreVersions/{VERSION}/appStoreVersionLocalizations")["data"][0]
existing = {s["attributes"]["screenshotDisplayType"]: s["id"]
            for s in call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]}
uploaded = []
for display, folder in SETS.items():
    set_id = existing.get(display) or call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
        "attributes": {"screenshotDisplayType": display},
        "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]["id"]
    for old in call("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots")["data"]:
        call("DELETE", f"/v1/appScreenshots/{old['id']}")
    for name in sorted(os.listdir(folder)):
        path = os.path.join(folder, name)
        shot = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
            "attributes": {"fileName": name, "fileSize": os.path.getsize(path)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
        data = open(path, "rb").read()
        for op in shot["attributes"]["uploadOperations"]:
            headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
            r = requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]:op["offset"] + op["length"]])
            r.raise_for_status()
        call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": md5(path)}}})
        uploaded.append((display, name, shot["id"]))
        print("uploaded", display, name, flush=True)

time.sleep(20)
for display, name, sid in uploaded:
    st = call("GET", f"/v1/appScreenshots/{sid}")["data"]["attributes"]["assetDeliveryState"]
    print(display, name, st["state"], [e.get("code") for e in st.get("errors") or []])
