#!/usr/bin/env bash
# Enhanced statusline with cached ccusage cost append.
#
# Behavior:
#   - Always returns in < 50ms (just stat + cat the cache file).
#   - Triggers an async background refresh of the ccusage cache when the
#     cache is older than 30s. The next prompt tick will see the new value.
#   - First-ever invocation may show no cost suffix until cache populates.
#
# Output:
#   [opus] XM_Opt_Backtest (branch) | in:20M out:132K | 💰$11/block (3h left) · 🔥$24/hr · 🧠13%

set -uo pipefail

JSON_INPUT="$(cat 2>/dev/null || echo '{}')"
CACHE_DIR="$HOME/.cache/claude-statusline"
CACHE_FILE="$CACHE_DIR/ccusage_suffix"
CACHE_TTL=30  # seconds
mkdir -p "$CACHE_DIR"

# === Original compact line (kept identical to existing statusline.sh) ===
CURRENT_DIR=$(jq -r '.workspace.current_dir // .workspace.project_dir // .cwd // ""' <<<"$JSON_INPUT" 2>/dev/null)
MODEL_NAME=$(jq -r '.model.display_name // .model.id // "claude"' <<<"$JSON_INPUT" 2>/dev/null)
TRANSCRIPT=$(jq -r '.transcript_path // ""' <<<"$JSON_INPUT" 2>/dev/null)
[ -z "$CURRENT_DIR" ] && CURRENT_DIR="$PWD"

case "$MODEL_NAME" in
    *Opus*|*opus*)     MODEL_SHORT="opus" ;;
    *Sonnet*|*sonnet*) MODEL_SHORT="sonnet" ;;
    *Haiku*|*haiku*)   MODEL_SHORT="haiku" ;;
    *)                 MODEL_SHORT=$(echo "$MODEL_NAME" | awk '{print tolower($1)}') ;;
esac

PROJECT_ALIAS_FILE="$CURRENT_DIR/.claude/project_alias"
if [ -f "$PROJECT_ALIAS_FILE" ]; then
    PROJECT=$(head -1 "$PROJECT_ALIAS_FILE" | tr -d '\n' | head -c 40)
else
    PROJECT=$(basename "$CURRENT_DIR")
fi

cd "$CURRENT_DIR" 2>/dev/null
BRANCH=""
if git rev-parse --git-dir >/dev/null 2>&1; then
    BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "")
fi

TOKENS_IN=0
TOKENS_OUT=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    TOKENS_IN=$(jq -r '
        (.message.usage.input_tokens // 0) +
        (.message.usage.cache_creation_input_tokens // 0) +
        (.message.usage.cache_read_input_tokens // 0)
    ' "$TRANSCRIPT" 2>/dev/null | awk '{s+=$1} END{print s+0}')
    TOKENS_OUT=$(jq -r '.message.usage.output_tokens // 0' "$TRANSCRIPT" 2>/dev/null \
        | awk '{s+=$1} END{print s+0}')
fi

fmt_tokens() {
    awk -v n="$1" 'BEGIN {
        if (n >= 1000000) printf "%.2fM", n/1000000
        else if (n >= 1000) printf "%.1fK", n/1000
        else printf "%d", n
    }'
}

IN_FMT=$(fmt_tokens "$TOKENS_IN")
OUT_FMT=$(fmt_tokens "$TOKENS_OUT")

LINE="[${MODEL_SHORT}] ${PROJECT}"
[ -n "$BRANCH" ] && LINE+=" (${BRANCH})"
LINE+=" | in:${IN_FMT} out:${OUT_FMT}"

# === Append cached ccusage suffix (always instant) ===
if [ -f "$CACHE_FILE" ]; then
    SUFFIX=$(cat "$CACHE_FILE" 2>/dev/null | tr -d '\n')
    [ -n "$SUFFIX" ] && LINE+=" | $SUFFIX"
fi

# === Trigger async refresh if cache is stale ===
if command -v npx >/dev/null 2>&1; then
    NEED_REFRESH=1
    if [ -f "$CACHE_FILE" ]; then
        AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
        [ "$AGE" -lt "$CACHE_TTL" ] && NEED_REFRESH=0
    fi
    if [ "$NEED_REFRESH" = "1" ] && [ ! -f "$CACHE_DIR/refresh.lock" ]; then
        # Spawn background refresh, lock to prevent concurrent refreshes
        (
            touch "$CACHE_DIR/refresh.lock"
            trap 'rm -f "$CACHE_DIR/refresh.lock"' EXIT
            CCUSAGE_OUT=$(echo "$JSON_INPUT" \
                | timeout 30 npx -y ccusage@latest statusline --offline --visual-burn-rate text 2>/dev/null \
                | sed 's/\x1b\[[0-9;]*m//g' || true)
            if [ -n "$CCUSAGE_OUT" ]; then
                echo "$CCUSAGE_OUT" \
                    | grep -v "❌" | grep -v "Invalid" \
                    | sed 's/^🤖[^|]*| *//' \
                    | tr -d '\n' \
                    > "$CACHE_FILE.tmp" \
                    && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
            fi
        ) >/dev/null 2>&1 < /dev/null &
        disown 2>/dev/null || true
    fi
fi

echo "$LINE"
