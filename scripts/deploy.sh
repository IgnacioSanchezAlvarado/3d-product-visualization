#!/usr/bin/env bash
# Platform deploy command: bash scripts/deploy.sh (run from the repo root).
#
# This fork has no platform-deployed infrastructure: the owner deploys the
# guidance by hand from docs/deploy-runbook.md (make -f makefile.aws deploy/main)
# and agents never deploy it. Every step below is therefore conditional, so the
# script is a safe no-op today and does the right thing if the repo later gains
# infra/, a Python app or systemd user units.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="3d-product-visualization"

# 1. CDK stacks under infra/ (none today; the guidance's own CDK lives in
#    deployment/ and is deployed by its CodePipeline, not by this script).
if [ -d infra ]; then
  : "${AGP_OUTPUTS_FILE:?AGP_OUTPUTS_FILE must be set by the deploy loop}"
  : "${CDK_DEFAULT_REGION:?CDK_DEFAULT_REGION must be set by the deploy loop}"
  echo "deploy: cdk deploy --all in infra/ (region $CDK_DEFAULT_REGION)"
  (cd infra && npm ci && npx cdk deploy --all --require-approval never --outputs-file "$AGP_OUTPUTS_FILE")

  # Runtime config: start from the existing config.json (keeping its values)
  # or config.example.json, then fill every stack output from the outputs file.
  if [ -f config.example.json ] || [ -f config.json ]; then
    python3 - "$AGP_OUTPUTS_FILE" <<'PY'
import json, os, sys
outputs = json.load(open(sys.argv[1]))
src = "config.json" if os.path.exists("config.json") else "config.example.json"
cfg = json.load(open(src))
for stack_outputs in outputs.values():
    cfg.update(stack_outputs)
with open("config.json", "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print(f"deploy: wrote config.json from {src} and {sys.argv[1]}")
PY
  fi
else
  echo "deploy: no infra/ directory, nothing to deploy with CDK (owner deploys the guidance from docs/deploy-runbook.md)"
fi

# 2. Python virtualenv (only when the repo has Python dependencies).
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  [ -x .venv/bin/python ] || python3 -m venv .venv
  .venv/bin/python -m pip install --quiet --upgrade pip
  if [ -f requirements.txt ]; then
    .venv/bin/python -m pip install --quiet -r requirements.txt
  else
    .venv/bin/python -m pip install --quiet .
  fi
  echo "deploy: .venv ready"
else
  echo "deploy: no requirements.txt or pyproject.toml, skipping .venv"
fi

# 3. systemd user units (only when the repo ships them in deploy/systemd/).
shopt -s nullglob
units=(deploy/systemd/*.service)
shopt -u nullglob
if [ ${#units[@]} -gt 0 ]; then
  unit_dir="$HOME/.config/systemd/user"
  mkdir -p "$unit_dir"
  for unit in "${units[@]}"; do
    sed -e "s#@REPO@#$PWD#g" -e "s#@PROJECT@#$PROJECT#g" "$unit" > "$unit_dir/$(basename "$unit")"
  done
  systemctl --user daemon-reload
  for unit in "${units[@]}"; do
    name="$(basename "$unit")"
    systemctl --user enable "$name"
    systemctl --user restart "$name"
  done
  echo "deploy: restarted ${#units[@]} systemd user unit(s)"
else
  echo "deploy: no systemd user units, nothing to restart"
fi

# 4. Health URL from the project document's "_Serves: port <n>, health <path>_" line.
serves="$(grep -m1 -oE '^_Serves: port [0-9]+, health [^_ ]+' docs/project.md 2>/dev/null || true)"
if [ -n "$serves" ]; then
  port="$(sed -E 's/^_Serves: port ([0-9]+).*/\1/' <<<"$serves")"
  path="$(sed -E 's/.*health ([^_ ]+).*/\1/' <<<"$serves")"
  url="http://127.0.0.1:${port}${path}"
  for _ in $(seq 1 60); do
    if curl -fsS -o /dev/null "$url"; then
      echo "deploy: $url is healthy"
      exit 0
    fi
    sleep 2
  done
  echo "deploy: $url did not answer within 120s" >&2
  exit 1
fi
echo "deploy: no _Serves line in docs/project.md, no health URL to wait for"
echo "deploy: done"
