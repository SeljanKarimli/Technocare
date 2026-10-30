#!/usr/bin/env bash
set -euo pipefail

api_base="${API_BASE_URL:-http://technocare-live-api.runasp.net/api}"
api_origin="${api_base%/api}"

curl --fail --silent --show-error "${api_origin%/}/health/live" >/dev/null
curl --fail --silent --show-error "${api_origin%/}/health/ready" >/dev/null

for route in home projects services education; do
  curl --fail --silent --show-error "${api_base%/}/v1/content/${route}" >/dev/null
done
for route in categories brands; do
  curl --fail --silent --show-error "${api_base%/}/v1/shop/${route}" >/dev/null
done
curl --fail --silent --show-error "${api_base%/}/notifications/public" >/dev/null

products="$(curl --fail --silent --show-error "${api_base%/}/v1/shop/products?page=1&pageSize=1")"
projects="$(curl --fail --silent --show-error "${api_base%/}/v1/content/projects?page=1&pageSize=50")"

python3 - "$products" "$projects" <<'PY'
import json
import sys

products = json.loads(sys.argv[1])
projects = json.loads(sys.argv[2])
if products.get("total", 0) < 8995:
    raise SystemExit(f"Expected at least 8995 products, got {products.get('total')}")
items = projects.get("items", [])
if projects.get("total") != 26 or len(items) != 26:
    raise SystemExit(f"Expected 26 projects, got total={projects.get('total')} items={len(items)}")
missing = [item.get("name", item.get("id")) for item in items if not item.get("imageUrl")]
if missing:
    raise SystemExit(f"Projects without primary images: {missing}")
print("Production smoke test passed: catalogue, projects, images and public routes are healthy.")
PY
