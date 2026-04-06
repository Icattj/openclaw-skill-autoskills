#!/usr/bin/env bash
# autoskills/scripts/recommend.sh — Map detected tech stack to skill recommendations
# Usage: bash detect.sh /path/to/project | bash recommend.sh
#    or: bash recommend.sh < detection.json
#    or: bash recommend.sh --detect /path/to/project
# Output: JSON with installed, available (clawhub), and external skill recommendations
# Requirements: bash 4+, jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_MAP="$SCRIPT_DIR/skills-map.json"
SKILLS_DIR="${OPENCLAW_SKILLS_DIR:-$HOME/.openclaw/workspace/skills}"

# ── Parse arguments ──────────────────────────────────────────────────────────
DETECTION_JSON=""

if [[ "${1:-}" == "--detect" ]] && [[ -n "${2:-}" ]]; then
  DETECTION_JSON=$("$SCRIPT_DIR/detect.sh" "$2")
elif [[ ! -t 0 ]]; then
  # Read from stdin (piped)
  DETECTION_JSON=$(cat)
else
  echo "Usage: bash detect.sh /path/to/project | bash recommend.sh" >&2
  echo "   or: bash recommend.sh --detect /path/to/project" >&2
  echo "   or: bash recommend.sh < detection.json" >&2
  exit 1
fi

if [[ -z "$DETECTION_JSON" ]]; then
  echo "Error: No detection input received." >&2
  exit 1
fi

# Validate JSON
if ! echo "$DETECTION_JSON" | jq . >/dev/null 2>&1; then
  echo "Error: Invalid JSON input." >&2
  exit 1
fi

# Validate skills map exists
if [[ ! -f "$SKILLS_MAP" ]]; then
  echo "Error: Skills map not found at $SKILLS_MAP" >&2
  exit 1
fi

# ── Collect all detected techs ──────────────────────────────────────────────
# Merge languages + frameworks + infrastructure into a single list
ALL_TECHS=$(echo "$DETECTION_JSON" | jq -r '
  ((.languages // []) + (.frameworks // []) + (.infrastructure // [])) | .[]
')

# ── Check which OpenClaw skills are actually installed ───────────────────────
is_skill_installed() {
  local skill="$1"
  [[ -d "$SKILLS_DIR/$skill" ]] && [[ -f "$SKILLS_DIR/$skill/SKILL.md" ]]
}

# ── Collect recommendations ──────────────────────────────────────────────────
# We use temp files to accumulate unique recommendations
INSTALLED_RECS=$(mktemp)
AVAILABLE_RECS=$(mktemp)
EXTERNAL_RECS=$(mktemp)
trap "rm -f '$INSTALLED_RECS' '$AVAILABLE_RECS' '$EXTERNAL_RECS'" EXIT

# Track already-recommended skills to avoid duplicates
declare -A SEEN_INSTALLED=()
declare -A SEEN_AVAILABLE=()
declare -A SEEN_EXTERNAL=()

add_recommendations() {
  local tech="$1"
  local reason="$2"

  # Look up tech in skills map
  local tech_entry
  tech_entry=$(jq -r --arg t "$tech" '.technologies[$t] // empty' "$SKILLS_MAP" 2>/dev/null) || true
  [[ -z "$tech_entry" ]] && return

  # OpenClaw skills
  local openclaw_skills
  openclaw_skills=$(echo "$tech_entry" | jq -r '.openclaw // [] | .[]' 2>/dev/null) || true
  for skill in $openclaw_skills; do
    [[ -z "$skill" ]] && continue
    if is_skill_installed "$skill"; then
      if [[ -z "${SEEN_INSTALLED[$skill]:-}" ]]; then
        SEEN_INSTALLED[$skill]=1
        echo "{\"skill\": \"$skill\", \"reason\": \"$reason\"}" >> "$INSTALLED_RECS"
      fi
    fi
  done

  # ClawHub skills
  local clawhub_skills
  clawhub_skills=$(echo "$tech_entry" | jq -r '.clawhub // [] | .[]' 2>/dev/null) || true
  for skill in $clawhub_skills; do
    [[ -z "$skill" ]] && continue
    if [[ -z "${SEEN_AVAILABLE[$skill]:-}" ]]; then
      SEEN_AVAILABLE[$skill]=1
      echo "{\"skill\": \"clawhub:$skill\", \"install\": \"clawhub install $skill\", \"reason\": \"$reason\"}" >> "$AVAILABLE_RECS"
    fi
  done

  # External skills
  local external_skills
  external_skills=$(echo "$tech_entry" | jq -r '.external // [] | .[]' 2>/dev/null) || true
  for skill in $external_skills; do
    [[ -z "$skill" ]] && continue
    if [[ -z "${SEEN_EXTERNAL[$skill]:-}" ]]; then
      SEEN_EXTERNAL[$skill]=1
      echo "{\"source\": \"skills.sh\", \"skill\": \"$skill\", \"reason\": \"$reason\"}" >> "$EXTERNAL_RECS"
    fi
  done
}

# ── Process individual technologies ──────────────────────────────────────────
for tech in $ALL_TECHS; do
  add_recommendations "$tech" "Detected $tech"
done

# ── Process combo detections ─────────────────────────────────────────────────
# Read all combo keys and check if all techs in the combo are detected
ALL_TECHS_ARRAY=$(echo "$DETECTION_JSON" | jq -r '
  ((.languages // []) + (.frameworks // []) + (.infrastructure // [])) | .[]
')

combos=$(jq -r '.combos // {} | keys[]' "$SKILLS_MAP" 2>/dev/null) || true
for combo in $combos; do
  [[ -z "$combo" ]] && continue

  # Split combo key on "+" and check all parts are in detected techs
  all_match=true
  IFS='+' read -ra COMBO_PARTS <<< "$combo"
  for part in "${COMBO_PARTS[@]}"; do
    found=false
    for tech in $ALL_TECHS_ARRAY; do
      if [[ "$tech" == "$part" ]]; then
        found=true
        break
      fi
    done
    if [[ "$found" == false ]]; then
      all_match=false
      break
    fi
  done

  if [[ "$all_match" == true ]]; then
    combo_display=$(echo "$combo" | tr '+' ' + ')
    reason="Combo detected: $combo_display"

    combo_entry=$(jq -r --arg c "$combo" '.combos[$c] // empty' "$SKILLS_MAP" 2>/dev/null) || true
    [[ -z "$combo_entry" ]] && continue

    # OpenClaw from combo
    local_combo_skills=$(echo "$combo_entry" | jq -r '.openclaw // [] | .[]' 2>/dev/null) || true
    for skill in $local_combo_skills; do
      [[ -z "$skill" ]] && continue
      if is_skill_installed "$skill"; then
        if [[ -z "${SEEN_INSTALLED[$skill]:-}" ]]; then
          SEEN_INSTALLED[$skill]=1
          echo "{\"skill\": \"$skill\", \"reason\": \"$reason\"}" >> "$INSTALLED_RECS"
        fi
      fi
    done

    # ClawHub from combo
    combo_clawhub=$(echo "$combo_entry" | jq -r '.clawhub // [] | .[]' 2>/dev/null) || true
    for skill in $combo_clawhub; do
      [[ -z "$skill" ]] && continue
      if [[ -z "${SEEN_AVAILABLE[$skill]:-}" ]]; then
        SEEN_AVAILABLE[$skill]=1
        echo "{\"skill\": \"clawhub:$skill\", \"install\": \"clawhub install $skill\", \"reason\": \"$reason\"}" >> "$AVAILABLE_RECS"
      fi
    done

    # External from combo
    combo_external=$(echo "$combo_entry" | jq -r '.external // [] | .[]' 2>/dev/null) || true
    for skill in $combo_external; do
      [[ -z "$skill" ]] && continue
      if [[ -z "${SEEN_EXTERNAL[$skill]:-}" ]]; then
        SEEN_EXTERNAL[$skill]=1
        echo "{\"source\": \"skills.sh\", \"skill\": \"$skill\", \"reason\": \"$reason\"}" >> "$EXTERNAL_RECS"
      fi
    done
  fi
done

# ── Build final JSON output ──────────────────────────────────────────────────
installed_json="[]"
available_json="[]"
external_json="[]"

if [[ -s "$INSTALLED_RECS" ]]; then
  installed_json=$(cat "$INSTALLED_RECS" | jq -s '.')
fi

if [[ -s "$AVAILABLE_RECS" ]]; then
  available_json=$(cat "$AVAILABLE_RECS" | jq -s '.')
fi

if [[ -s "$EXTERNAL_RECS" ]]; then
  external_json=$(cat "$EXTERNAL_RECS" | jq -s '.')
fi

jq -n \
  --argjson installed "$installed_json" \
  --argjson available "$available_json" \
  --argjson external "$external_json" \
  --argjson detection "$DETECTION_JSON" \
  '{
    detection: $detection,
    recommendations: {
      installed: $installed,
      available: $available,
      external: $external
    },
    summary: {
      totalInstalled: ($installed | length),
      totalAvailable: ($available | length),
      totalExternal: ($external | length)
    }
  }'
