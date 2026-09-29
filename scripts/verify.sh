#!/usr/bin/env bash
# Platform verify command: bash scripts/verify.sh (run from the repo root).
# Exits non-zero when anything is wrong; the deploy loop rolls back on failure.
set -uo pipefail

cd "$(dirname "$0")/.."
fail=0
check() { if "$@"; then echo "ok:   $CHECK"; else echo "FAIL: $CHECK" >&2; fail=1; fi; }

# 1. Previous verify_cmd: showcase content and launcher.json.
CHECK="scripts/verify-showcase.sh"; check bash scripts/verify-showcase.sh

# 2. CloudFormation stacks from infra/ (none today; the owner deploys the guidance by hand).
if [ -d infra ] && [ -n "${AGP_OUTPUTS_FILE:-}" ] && [ -f "$AGP_OUTPUTS_FILE" ]; then
  for stack in $(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))))' "$AGP_OUTPUTS_FILE"); do
    status="$(aws cloudformation describe-stacks --stack-name "$stack" --region "${CDK_DEFAULT_REGION:?}" \
      --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo MISSING)"
    CHECK="stack $stack is $status"; check grep -qE '^(CREATE|UPDATE)_COMPLETE$' <<<"$status"
  done
else
  echo "skip: no infra/ stacks to check"
fi

# 3. Python dependencies in .venv.
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  mods="$(sed -E 's/[#;].*//; s/\[.*//; s/[<>=!~ ].*//' requirements.txt 2>/dev/null | grep -v '^-' | grep . | tr '-' '_' | tr 'A-Z' 'a-z' | paste -sd, -)"
  CHECK=".venv/bin/python imports ${mods:-nothing}"; check .venv/bin/python -c "import ${mods:-sys}"
else
  echo "skip: no Python dependencies"
fi

# 4. systemd user units.
shopt -s nullglob
for unit in deploy/systemd/*.service; do
  CHECK="unit $(basename "$unit") active"; check systemctl --user is-active --quiet "$(basename "$unit")"
done
shopt -u nullglob

# 5. Health URL from docs/project.md "_Serves: port <n>, health <path>_".
serves="$(grep -m1 -oE '^_Serves: port [0-9]+, health [^_ ]+' docs/project.md 2>/dev/null || true)"
if [ -n "$serves" ]; then
  port="$(sed -E 's/^_Serves: port ([0-9]+).*/\1/' <<<"$serves")"
  path="$(sed -E 's/.*health ([^_ ]+).*/\1/' <<<"$serves")"
  CHECK="health http://127.0.0.1:${port}${path}"; check curl -fsS -o /dev/null "http://127.0.0.1:${port}${path}"
else
  echo "skip: no health URL declared"
fi

[ "$fail" -eq 0 ] && echo "verify: all checks passed"
exit "$fail"
