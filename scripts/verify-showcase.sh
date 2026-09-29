#!/usr/bin/env bash
# Machine check of the project's success criteria: showcase content and launcher.json.
# Run from anywhere: bash scripts/verify-showcase.sh. Exits 1 when any check fails.
set -uo pipefail

cd "$(dirname "$0")/.."
fail=0
ok()  { echo "ok: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

# 1. docs/showcase.md front section and required headings.
md=docs/showcase.md
if [ -f "$md" ]; then
  head_section="$(awk '/^## /{exit} {print}' "$md")"
  if grep -q '^tagline:' <<<"$head_section" && grep -q '^tags:' <<<"$head_section" \
     && grep -qx '## Story' "$md" && grep -qx '## Architecture' "$md"; then
    ok "$md has tagline, tags, ## Story and ## Architecture"
  else
    bad "$md is missing tagline:/tags: in its first section or a ## Story / ## Architecture heading"
  fi
else
  bad "$md does not exist"
fi

# 2. The Architecture section embeds an image that exists (relative to docs/, or to the repo root).
img="$(awk '/^## /{on=($0=="## Architecture")} on' "$md" 2>/dev/null \
  | grep -oE '!\[[^]]*\]\([^) ]+' | head -n1 | sed -E 's/.*\(//')"
if [ -z "$img" ]; then
  bad "$md ## Architecture embeds no image"
elif [ -f "docs/$img" ] || [ -f "$img" ]; then
  ok "$md ## Architecture image $img exists"
else
  bad "$md ## Architecture image $img not found"
fi

# 3. At least one PNG in docs/showcase/.
if compgen -G 'docs/showcase/*.png' >/dev/null; then
  ok "docs/showcase/ has PNG files"
else
  bad "docs/showcase/ has no *.png"
fi

# 4. launcher.json parses and has the demo-launcher fields.
if [ -f launcher.json ] && python3 -m json.tool launcher.json >/dev/null 2>&1; then
  if err="$(python3 -c '
import json, sys
d = json.load(open("launcher.json"))
errs = [k for k in ("name", "title", "provider", "region", "start", "stop", "keep",
                    "hourly_cost_usd", "url_source", "max_running_minutes") if k not in d]
if d.get("provider") != "gamelift-streams": errs.append("provider != gamelift-streams")
if d.get("hourly_cost_usd") != 3.0: errs.append("hourly_cost_usd != 3.0")
if d.get("max_running_minutes") != 120: errs.append("max_running_minutes != 120")
for s in ("start", "stop"):
    v = d.get(s) if isinstance(d.get(s), dict) else {}
    errs += [f"{s}.{k}" for k in ("stream_group_id", "location", "always_on_capacity_min",
                                  "on_demand_capacity_min") if k not in v]
if errs: sys.exit(", ".join(errs))
' 2>&1)"; then
    ok "launcher.json has the required fields"
  else
    bad "launcher.json fields: $err"
  fi
else
  bad "launcher.json is missing or not valid JSON"
fi

# 5. No 12-digit numbers (account ids) in tracked text files.
hits="$(git ls-files -z docs scripts launcher.json .gitignore | xargs -0 -r grep -IlE '[0-9]{12}' 2>/dev/null)"
if [ -z "$hits" ]; then
  ok "no 12-digit numbers in docs/, scripts/, launcher.json, .gitignore"
else
  bad "12-digit numbers found in: $(echo $hits)"
fi

exit "$fail"
