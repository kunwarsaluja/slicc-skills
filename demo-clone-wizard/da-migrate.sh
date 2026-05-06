#!/bin/bash
# DA cross-org content migration: GET from source, POST to target
# Sends sprinkle progress updates directly
# Usage: bash da-migrate.sh <source_org> <source_repo> <target_org> <target_repo> <token>

SOURCE_ORG=$1
SOURCE_REPO=$2
TARGET_ORG=$3
TARGET_REPO=$4
TOKEN=$5

# Paths to skip (relative to repo root, no leading slash)
SKIP_PATHS="demo-docs drafts"

WORK_DIR="/tmp/da-migrate-$$"
mkdir -p "$WORK_DIR"
COUNTER_FILE="$WORK_DIR/counter"
PARSE_SCRIPT="$WORK_DIR/parse.py"
echo "0 0" > "$COUNTER_FILE"

# Write the parse script once
cat > "$PARSE_SCRIPT" << 'PYEOF'
import sys, json
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    for item in data:
        ext = item.get('ext', '')
        path = item.get('path', '')
        if ext:
            print('FILE:' + path + ':' + ext)
        elif path:
            print('DIR:' + path)
except Exception as e:
    sys.stderr.write('ERR: ' + str(e) + '\n')
PYEOF

send_progress() {
  local msg="$1"
  local escaped
  escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
  sprinkle send demo-clone-wizard "{\"action\":\"copy-progress\",\"message\":\"${escaped}\"}"
}

increment_copied() {
  local copied errors
  read -r copied errors < "$COUNTER_FILE"
  copied=$((copied + 1))
  printf '%s %s\n' "$copied" "$errors" > "$COUNTER_FILE"
  if [ $((copied % 10)) -eq 0 ]; then
    send_progress "Copied ${copied} files..."
  fi
}

increment_errors() {
  local path="$1" code="$2"
  local copied errors
  read -r copied errors < "$COUNTER_FILE"
  errors=$((errors + 1))
  printf '%s %s\n' "$copied" "$errors" > "$COUNTER_FILE"
  send_progress "Warning: failed ${path} (HTTP ${code})"
}

should_skip() {
  local rel_path="$1"   # e.g. /demo-docs or /drafts/kunwar
  local clean="${rel_path#/}"  # strip leading slash
  local skip
  for skip in $SKIP_PATHS; do
    # Match exact name or any subpath using case (POSIX-safe, no [[ needed)
    case "$clean" in
      "$skip"|"$skip"/*)
        return 0 ;;
    esac
  done
  return 1
}

crawl_and_copy() {
  local current_path="$1"

  # Skip excluded top-level folders
  if should_skip "$current_path"; then
    return
  fi

  local list_url="https://admin.da.live/list/${SOURCE_ORG}/${SOURCE_REPO}${current_path}"
  local tmpjson="$WORK_DIR/list$$.json"
  curl -s -H "Authorization: Bearer ${TOKEN}" "$list_url" > "$tmpjson"

  local items
  items=$(python3 "$PARSE_SCRIPT" "$tmpjson")
  rm -f "$tmpjson"

  while IFS= read -r item; do
    [[ -z "$item" ]] && continue

    if [[ "$item" == FILE:* ]]; then
      local payload="${item#FILE:}"
      local ext="${payload##*:}"
      local file_path="${payload%:*}"
      local rel_path="${file_path#/${SOURCE_ORG}/${SOURCE_REPO}}"

      # Skip if this file is under an excluded path
      if should_skip "$rel_path"; then
        continue
      fi

      local source_url="https://admin.da.live/source/${SOURCE_ORG}/${SOURCE_REPO}${rel_path}"
      local target_url="https://admin.da.live/source/${TARGET_ORG}/${TARGET_REPO}${rel_path}"

      local ctype="text/html"
      case "$ext" in
        json)     ctype="application/json" ;;
        svg)      ctype="image/svg+xml" ;;
        png)      ctype="image/png" ;;
        jpg|jpeg) ctype="image/jpeg" ;;
        mp4)      ctype="video/mp4" ;;
        pdf)      ctype="application/pdf" ;;
        css)      ctype="text/css" ;;
        js)       ctype="application/javascript" ;;
      esac

      local tmpbody="$WORK_DIR/body$$.bin"

      # Download — check HTTP code; skip upload if source missing
      local dl_code
      dl_code=$(curl -s -o "$tmpbody" -w "%{http_code}" \
        -H "Authorization: Bearer ${TOKEN}" "$source_url")

      if [ "$dl_code" != "200" ]; then
        increment_errors "$rel_path" "dl:${dl_code}"
        rm -f "$tmpbody"
        continue
      fi

      # Upload
      local ul_code
      ul_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$target_url" \
        -H "Authorization: Bearer ${TOKEN}" \
        -F "data=@${tmpbody};type=${ctype}")

      rm -f "$tmpbody"

      if [ "$ul_code" = "200" ] || [ "$ul_code" = "201" ]; then
        increment_copied
      else
        increment_errors "$rel_path" "$ul_code"
      fi

    elif [[ "$item" == DIR:* ]]; then
      local dir_path="${item#DIR:}"
      local rel_dir="${dir_path#/${SOURCE_ORG}/${SOURCE_REPO}}"

      if should_skip "$rel_dir"; then
        send_progress "Skipping: ${rel_dir}"
        continue
      fi

      send_progress "Scanning: ${rel_dir}"
      crawl_and_copy "${rel_dir}"
    fi
  done <<< "$items"
}

send_progress "Crawling ${SOURCE_ORG}/${SOURCE_REPO} content tree..."
crawl_and_copy ""

# Read final counts
read -r COPIED ERRORS < "$COUNTER_FILE"
rm -rf "$WORK_DIR"

if [ "$ERRORS" -eq 0 ]; then
  sprinkle send demo-clone-wizard "{\"action\":\"copy-done\",\"count\":${COPIED}}"
else
  sprinkle send demo-clone-wizard "{\"action\":\"copy-done\",\"count\":${COPIED},\"errors\":${ERRORS}}"
fi
