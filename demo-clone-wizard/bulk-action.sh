#!/bin/bash
# Usage: bash bulk-action.sh <action:preview|publish> <org> <repo> <token>
ACTION=$1  # "preview" or "publish"
ORG=$2
REPO=$3
TOKEN=$4

PARSE_SCRIPT="/scoops/demo-clone-wizard-scoop/bulk-parse.py"

# Write parser script
cat > "$PARSE_SCRIPT" << 'PYEOF'
import sys, json

result = sys.argv[1]
org_repo_prefix = sys.argv[2]  # e.g. /kunwarsaluja/demo

try:
    data = json.loads(result)
    for item in data:
        ext = item.get('ext', '')
        p = item.get('path', '')
        rel = p.replace(org_repo_prefix, '', 1)
        if ext == 'html':
            print('PAGE:' + rel.replace('.html', ''))
        elif not ext and rel not in ['/drafts', '/icons', '/demo-slides', '/demo-docs']:
            print('DIR:' + rel)
except Exception as e:
    sys.stderr.write('PARSE ERR: ' + str(e) + '\n')
PYEOF

sprinkle send demo-clone-wizard "{\"action\":\"status\",\"message\":\"Collecting all page paths...\",\"type\":\"notice\"}"

# Collect paths at a given path level — write to a temp file (avoids stdin consumption)
collect_paths() {
  local path="$1"
  local tmpout="/scoops/demo-clone-wizard-scoop/bulk-list-$$.txt"
  local result
  result=$(curl -s -H "Authorization: Bearer $TOKEN" "https://admin.da.live/list/${ORG}/${REPO}${path}")
  python3 "$PARSE_SCRIPT" "$result" "/${ORG}/${REPO}" > "$tmpout" 2>/dev/null
  echo "$tmpout"
}

# Recursive crawl — build ALL_PAGES array
ALL_PAGES=()

crawl() {
  local path="$1"
  local tmpout
  tmpout=$(collect_paths "$path")

  local -a items
  mapfile -t items < "$tmpout"
  rm -f "$tmpout"

  for line in "${items[@]}"; do
    if [[ "$line" == PAGE:* ]]; then
      ALL_PAGES+=("${line#PAGE:}")
    elif [[ "$line" == DIR:* ]]; then
      crawl "${line#DIR:}"
    fi
  done
}

crawl ""

COUNT=${#ALL_PAGES[@]}
sprinkle send demo-clone-wizard "{\"action\":\"status\",\"message\":\"Found ${COUNT} pages — starting bulk ${ACTION}...\",\"type\":\"notice\"}"

# Build JSON paths array via python
PATHS_JSON=$(printf '%s\n' "${ALL_PAGES[@]}" | python3 -c "
import sys, json
paths = [line.strip() for line in sys.stdin if line.strip()]
print(json.dumps(paths))
")

# Determine API endpoint
if [ "$ACTION" = "preview" ]; then
  ENDPOINT="https://admin.hlx.page/preview/${ORG}/${REPO}/main"
  TRIGGERED_ACTION="preview-triggered"
else
  ENDPOINT="https://admin.hlx.page/live/${ORG}/${REPO}/main"
  TRIGGERED_ACTION="publish-triggered"
fi

# POST the bulk job
BODY="{\"paths\":${PATHS_JSON},\"forceUpdate\":true}"
OUTFILE="/scoops/demo-clone-wizard-scoop/bulk-action-out.txt"
RAW=$(curl -s -w "\nHTTP:%{http_code}" \
  -X POST "$ENDPOINT" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY")
HTTP_CODE=$(echo "$RAW" | grep "^HTTP:" | cut -d: -f2)
RESP=$(echo "$RAW" | grep -v "^HTTP:")

echo "HTTP: $HTTP_CODE"
echo "RESP: ${RESP:0:200}"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "202" ]; then
  sprinkle send demo-clone-wizard "{\"action\":\"${TRIGGERED_ACTION}\"}"
  sprinkle send demo-clone-wizard "{\"action\":\"status\",\"message\":\"Bulk ${ACTION} started for ${COUNT} pages\",\"type\":\"positive\"}"
else
  sprinkle send demo-clone-wizard "{\"action\":\"status\",\"message\":\"Bulk ${ACTION} failed (HTTP ${HTTP_CODE})\",\"type\":\"negative\"}"
fi

rm -f "$PARSE_SCRIPT"
