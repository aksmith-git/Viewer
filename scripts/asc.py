"""Tiny App Store Connect API helper.  Env: ASC_KEY_ID, ASC_ISSUER, ASC_KEY_PATH."""
import os, time, json, hashlib, jwt, requests

BASE = "https://api.appstoreconnect.apple.com"

def token():
    key = open(os.path.expanduser(os.environ["ASC_KEY_PATH"])).read()
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

def call(method, path, body=None, params=None, ok=(200, 201, 204)):
    r = requests.request(method, BASE + path if path.startswith("/") else path, params=params,
                         headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"},
                         data=json.dumps(body) if body is not None else None)
    if r.status_code not in ok:
        raise SystemExit(f"{method} {path} -> {r.status_code}\n{r.text[:1500]}")
    return r.json() if r.text else {}

def md5(path):
    return hashlib.md5(open(path, "rb").read()).hexdigest()
