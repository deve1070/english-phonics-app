"""Walks every basic function of the phonics backend against a live server.

Reports PASS/FAIL per function with the actual response so failures are
diagnosable, rather than just asserting.
"""
import json
import sys
import time

import httpx as requests

B = "http://127.0.0.1:8000/api/v1"
results = []


def check(name, ok, detail=""):
    results.append((name, ok, detail))
    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {name}" + (f"\n       {detail}" if detail else ""))
    return ok


def jd(r):
    try:
        return r.json()
    except Exception:
        return r.text[:200]


PHONE = f"+2519{int(time.time()) % 100000000:08d}"
KID = f"kid{int(time.time()) % 1000000}"

print("=" * 70)
print("AUTH")
print("=" * 70)

r = requests.post(f"{B}/parents/register", json={
    "name": "Verify Parent", "phone_number": PHONE,
    "child": {"name": "Verify Child", "user_name": KID, "nickname": "Buddy"},
})
reg = jd(r)
check("parent+child registration", r.status_code == 201 and "access_token" in reg,
      f"HTTP {r.status_code} keys={list(reg) if isinstance(reg, dict) else reg}")
CHILD_ID = reg["child"]["id"]
PARENT_ID = reg["parent_id"]

r = requests.post(f"{B}/auth/login", json={"phone_number": PHONE})
login = jd(r)
check("passwordless login (phone only)", r.status_code == 200 and "access_token" in login,
      f"HTTP {r.status_code}")
AT = login["access_token"]
BT = login["biometric_token"]
H = {"Authorization": f"Bearer {AT}"}

r = requests.post(f"{B}/auth/login", json={"phone_number": "+251900000001"})
check("login with unknown phone is rejected", r.status_code in (401, 404),
      f"HTTP {r.status_code}")

r = requests.get(f"{B}/users/me", headers=H)
me = jd(r)
check("GET /users/me", r.status_code == 200 and me.get("phone_number") == PHONE,
      f"HTTP {r.status_code} role={me.get('role')}")
check("/users/me has no age_group or email field",
      "age_group" not in me and "email" not in me,
      f"fields={sorted(me)}")

r = requests.post(f"{B}/auth/passkey-login", json={"biometric_token": BT})
pk = jd(r)
rotated = pk.get("biometric_token")
check("passkey-login redeems biometric token", r.status_code == 200 and "access_token" in pk,
      f"HTTP {r.status_code}")
check("biometric token rotates on use", rotated and rotated != BT,
      f"old={BT[:10]}... new={str(rotated)[:10]}...")

r = requests.post(f"{B}/auth/passkey-login", json={"biometric_token": BT})
check("reused biometric token is rejected", r.status_code == 401, f"HTTP {r.status_code}")

r = requests.get(f"{B}/users/me")
check("unauthenticated /users/me is rejected", r.status_code in (401, 403), f"HTTP {r.status_code}")

print()
print("=" * 70)
print("PARENT DASHBOARD")
print("=" * 70)

r = requests.get(f"{B}/parents/dashboard", headers=H)
dash = jd(r)
check("GET /parents/dashboard", r.status_code == 200 and dash.get("total_children") == 1,
      f"HTTP {r.status_code} children={dash.get('total_children')}")

r = requests.post(f"{B}/parents/children", headers=H,
                  json={"name": "Second Child", "user_name": KID + "b"})
c2 = jd(r)
check("add a second child", r.status_code in (200, 201) and "id" in c2, f"HTTP {r.status_code}")
CHILD2 = c2.get("id")

r = requests.get(f"{B}/parents/children", headers=H)
kids = jd(r)
check("list children reflects both", r.status_code == 200 and len(kids) == 2,
      f"HTTP {r.status_code} n={len(kids) if isinstance(kids, list) else kids}")

r = requests.get(f"{B}/parents/children/{CHILD_ID}/progress", headers=H)
prog = jd(r)
check("child progress detail", r.status_code == 200 and "phoneme_progress" in prog,
      f"HTTP {r.status_code}")

r = requests.get(f"{B}/parents/children/{CHILD_ID}/goals", headers=H)
check("read learning goals", r.status_code == 200, f"HTTP {r.status_code} {jd(r)}")

r = requests.put(f"{B}/parents/children/{CHILD_ID}/goals", headers=H,
                 json={"daily_minutes_target": 25, "lessons_per_week": 4, "max_daily_minutes": 45})
g = jd(r)
check("update learning goals persists", r.status_code == 200 and g.get("daily_minutes_target") == 25,
      f"HTTP {r.status_code} {g}")

r = requests.post(f"{B}/parents/children/{CHILD_ID}/child-login")
r = requests.post(f"{B}/parents/child-login/{CHILD_ID}", headers=H)
cl = jd(r)
check("switch into child session", r.status_code == 200 and "access_token" in cl,
      f"HTTP {r.status_code} expires_in={cl.get('expires_in_seconds')}")
CT = cl["access_token"]
CH = {"Authorization": f"Bearer {CT}"}

print()
print("=" * 70)
print("AUTHORIZATION BOUNDARIES")
print("=" * 70)

r = requests.get(f"{B}/parents/dashboard", headers=CH)
check("child token cannot read parent dashboard", r.status_code in (401, 403), f"HTTP {r.status_code}")

r = requests.get(f"{B}/parents/children/{CHILD_ID}/progress", headers=CH)
check("child token cannot read parent progress view", r.status_code in (401, 403),
      f"HTTP {r.status_code}")

# A second, unrelated parent must not see the first parent's child.
PHONE2 = f"+2519{(int(time.time()) + 7) % 100000000:08d}"
r = requests.post(f"{B}/parents/register", json={
    "name": "Other Parent", "phone_number": PHONE2,
    "child": {"name": "Other Child", "user_name": KID + "z"}})
other = jd(r)
OH = {"Authorization": f"Bearer {other['access_token']}"}
r = requests.get(f"{B}/parents/children/{CHILD_ID}/progress", headers=OH)
check("another parent cannot read this child's progress", r.status_code in (403, 404),
      f"HTTP {r.status_code}")
r = requests.post(f"{B}/parents/child-login/{CHILD_ID}", headers=OH)
check("another parent cannot log in as this child", r.status_code in (403, 404),
      f"HTTP {r.status_code}")

print()
print("=" * 70)
print("SCREEN TIME")
print("=" * 70)

r = requests.post(f"{B}/parents/children/{CHILD_ID}/start-session", headers=H)
check("start screen-time session", r.status_code in (200, 201), f"HTTP {r.status_code} {jd(r)}")

r = requests.get(f"{B}/parents/children/{CHILD_ID}/screen-time", headers=H)
check("read screen-time", r.status_code == 200, f"HTTP {r.status_code} {jd(r)}")

r = requests.post(f"{B}/parents/children/{CHILD_ID}/end-session", headers=CH,
                  json={"session_start": "2026-01-01T00:00:00Z"})
check("child's own token can end the session", r.status_code in (200, 201),
      f"HTTP {r.status_code} {jd(r)}")

print()
print("=" * 70)
print("CURRICULUM (as the child)")
print("=" * 70)

r = requests.get(f"{B}/lessons/", headers=CH)
lessons = jd(r)
check("list lessons", r.status_code == 200 and isinstance(lessons, list) and lessons,
      f"HTTP {r.status_code} n={len(lessons) if isinstance(lessons, list) else 0}")
L1 = lessons[0]
check("lesson list carries server-computed progress counts",
      "completed_exercises" in L1 and "total_exercises" in L1,
      f"keys={sorted(L1)}")

r = requests.get(f"{B}/lessons/{L1['id']}", headers=CH)
ld = jd(r)
check("lesson detail includes phonemes", r.status_code == 200 and "phonemes" in ld,
      f"HTTP {r.status_code} phonemes={len(ld.get('phonemes', []))}")

r = requests.get(f"{B}/lessons/{L1['id']}/exercises", headers=CH)
exs = jd(r)
check("lesson exercises endpoint responds", r.status_code == 200,
      f"HTTP {r.status_code} n={len(exs) if isinstance(exs, list) else exs}")

r = requests.get(f"{B}/phonemes/", headers=CH)
phs = jd(r)
check("list phonemes", r.status_code == 200 and isinstance(phs, list) and phs,
      f"HTTP {r.status_code} n={len(phs) if isinstance(phs, list) else 0}")
P1 = phs[0]

r = requests.get(f"{B}/phonemes/{P1['id']}", headers=CH)
check("phoneme detail", r.status_code == 200, f"HTTP {r.status_code}")

r = requests.get(f"{B}/phonemes/{P1['id']}/audio", headers=CH)
check("phoneme reference audio streams", r.status_code == 200 and len(r.content) > 500,
      f"HTTP {r.status_code} bytes={len(r.content)} type={r.headers.get('content-type')}")

print()
print("=" * 70)
print("SUMMARY")
print("=" * 70)
passed = sum(1 for _, ok, _ in results if ok)
failed = [n for n, ok, _ in results if not ok]
print(f"{passed}/{len(results)} passed")
if failed:
    print("\nFAILED:")
    for n in failed:
        print(f"  - {n}")
json.dump({"exercises_seeded": 0}, open("/dev/null", "w"))
sys.exit(1 if failed else 0)
