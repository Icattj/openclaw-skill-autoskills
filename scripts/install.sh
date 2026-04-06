#!/usr/bin/env bash
# autoskills/scripts/install.sh — Install recommended skills
# Usage: bash install.sh <skill-name> [--from clawhub|skills.sh]
# Requirements: bash 4+, clawhub CLI (for clawhub installs)

set -euo pipefail

SKILL_NAME="${1:-}"
SOURCE="${3:-clawhub}"  # Default source

# ── Parse arguments ──────────────────────────────────────────────────────────
if [[ -z "$SKILL_NAME" ]]; then
  echo "Usage: bash install.sh <skill-name> [--from clawhub|skills.sh]" >&2
  echo "" >&2
  echo "Sources:" >&2
  echo "  clawhub    Install from clawhub.com (default)" >&2
  echo "  skills.sh  Show instructions for skills.sh import" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  bash install.sh nextjs-best-practices" >&2
  echo "  bash install.sh nextjs-best-practices --from clawhub" >&2
  echo "  bash install.sh vercel-labs/next-skills/next-best-practices --from skills.sh" >&2
  exit 1
fi

# Parse --from flag
if [[ "${2:-}" == "--from" ]] && [[ -n "${3:-}" ]]; then
  SOURCE="$3"
fi

# ── Install based on source ──────────────────────────────────────────────────
case "$SOURCE" in
  clawhub)
    echo "📦 Installing '$SKILL_NAME' from ClawHub..."
    
    # Check if clawhub CLI is available
    if ! command -v clawhub >/dev/null 2>&1; then
      echo "⚠️  ClawHub CLI not found. Attempting npx..." >&2
      if command -v npx >/dev/null 2>&1; then
        npx clawhub install "$SKILL_NAME"
      else
        echo "❌ Neither 'clawhub' nor 'npx' found." >&2
        echo "" >&2
        echo "Install ClawHub CLI first:" >&2
        echo "  npm install -g clawhub" >&2
        echo "" >&2
        echo "Then run:" >&2
        echo "  clawhub install $SKILL_NAME" >&2
        exit 1
      fi
    else
      clawhub install "$SKILL_NAME"
    fi

    echo "✅ Installed '$SKILL_NAME' from ClawHub."
    ;;

  skills.sh)
    # skills.sh skills are typically GitHub-hosted .md files
    # Format: owner/repo/path or owner/repo-name/skill-name
    echo "📋 External skill from skills.sh: $SKILL_NAME"
    echo ""
    echo "Skills.sh skills are GitHub-hosted agent skill files."
    echo "To use this skill, you can:"
    echo ""
    echo "  1. Browse: https://skills.sh"
    echo "     Search for: $SKILL_NAME"
    echo ""
    echo "  2. Direct GitHub URL:"
    echo "     https://github.com/$SKILL_NAME"
    echo ""
    echo "  3. Import to OpenClaw workspace:"
    echo "     # Download the skill content"
    IFS='/' read -ra PARTS <<< "$SKILL_NAME"
    local_name="${PARTS[${#PARTS[@]}-1]}"
    echo "     mkdir -p ~/.openclaw/workspace/skills/$local_name"
    echo "     curl -sL \"https://raw.githubusercontent.com/${PARTS[0]}/${PARTS[1]}/main/${PARTS[2]:+${PARTS[2]}/}.md\" \\"
    echo "       > ~/.openclaw/workspace/skills/$local_name/SKILL.md"
    echo ""
    echo "  4. Or use the skill-absorber skill to auto-convert:"
    echo "     # This converts external skills to OpenClaw format"
    echo "     → Ask your agent to absorb: https://github.com/$SKILL_NAME"
    echo ""
    echo "Note: External skills may need adaptation for OpenClaw."
    ;;

  *)
    echo "❌ Unknown source: $SOURCE" >&2
    echo "Supported sources: clawhub, skills.sh" >&2
    exit 1
    ;;
esac
