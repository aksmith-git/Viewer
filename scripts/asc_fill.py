import re, sys
sys.path.insert(0, "scripts")
from asc import call

APP, VERSION, BUILD = sys.argv[1:4]
md = open("appstore/metadata.md").read()
def section(title):
    m = re.search(r"^## " + re.escape(title) + r".*?\n(.*?)(?=^## |\Z)", md, re.S | re.M)
    return m.group(1).strip()
description = section("Description")
promo = section("Promotional text (170 max)")
keywords = "html,javascript,web,file,markdown,json,csv,code,zip,pdf,docx,reader,preview,source,console,offline"

# app info: categories + localization (name, subtitle, privacy URL)
infos = call("GET", f"/v1/apps/{APP}/appInfos")["data"]
info = next(i for i in infos if i["attributes"].get("appStoreState", i["attributes"].get("state")) not in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION")) if len(infos) > 1 else infos[0]
call("PATCH", f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
    "primaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}},
    "secondaryCategory": {"data": {"type": "appCategories", "id": "DEVELOPER_TOOLS"}}}}})
for loc in call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]:
    call("PATCH", f"/v1/appInfoLocalizations/{loc['id']}", {"data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": {
        "subtitle": "Web pages, code, PDFs & more",
        "privacyPolicyUrl": "https://aksmith-git.github.io/Viewer/privacy.html"}}})
    print("app info localization", loc["attributes"]["locale"], "updated")

# version localization
for loc in call("GET", f"/v1/appStoreVersions/{VERSION}/appStoreVersionLocalizations")["data"]:
    call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {
        "description": description, "keywords": keywords, "promotionalText": promo,
        "supportUrl": "https://aksmith-git.github.io/Viewer/", "marketingUrl": "https://aksmith-git.github.io/Viewer/"}}})
    print("version localization", loc["attributes"]["locale"], "updated")

# version: copyright + build
call("PATCH", f"/v1/appStoreVersions/{VERSION}", {"data": {"type": "appStoreVersions", "id": VERSION,
    "attributes": {"copyright": "2026 Adrian Smith", "releaseType": "AFTER_APPROVAL"},
    "relationships": {"build": {"data": {"type": "builds", "id": BUILD}}}}})
print("version: copyright set, build attached")

# age rating: nothing objectionable
decl = call("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration")["data"]
attrs = {}
for k, v in decl["attributes"].items():
    if isinstance(v, bool) or v is None and k.startswith(("is", "has", "contains")) or k in ("gambling", "unrestrictedWebAccess", "lootBox", "messagingAndChat", "parentalControls", "ageAssurance", "advertising", "userGeneratedContent", "healthOrWellnessTopics", "socialMedia", "socialMediaAgeRestricted"):
        attrs[k] = False
    elif isinstance(v, str) or (v is None and k not in ("kidsAgeBand", "ageRatingOverride", "ageRatingOverrideV2", "koreaAgeRatingOverride")):
        attrs[k] = "NONE"
for k in [k for k in attrs if k.startswith(("grac", "korea", "ageRatingOverride", "kidsAgeBand", "developerAgeRating"))]:
    attrs.pop(k, None)
print("age rating fields:", sorted(attrs))
call("PATCH", f"/v1/ageRatingDeclarations/{decl['id']}", {"data": {"type": "ageRatingDeclarations", "id": decl["id"], "attributes": attrs}})
print("age rating: all none")
