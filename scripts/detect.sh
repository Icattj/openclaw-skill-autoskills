#!/usr/bin/env bash
# autoskills/scripts/detect.sh — Detect project tech stack
# Usage: bash detect.sh [project-dir]
# Output: JSON to stdout with detected languages, frameworks, infrastructure
# Requirements: bash 4+, jq

set -euo pipefail

PROJECT_DIR="${1:-.}"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: Directory '$PROJECT_DIR' does not exist." >&2
  exit 1
fi

# Normalize to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# ── Arrays to collect detections ──────────────────────────────────────────────
declare -a LANGUAGES=()
declare -a FRAMEWORKS=()
declare -a INFRASTRUCTURE=()
PACKAGE_MANAGER=""
IS_FRONTEND=false
IS_BACKEND=false

# ── Helper: add unique to array ───────────────────────────────────────────────
add_lang()    { for v in "${LANGUAGES[@]:-}";      do [[ "$v" == "$1" ]] && return; done; LANGUAGES+=("$1"); }
add_fw()      { for v in "${FRAMEWORKS[@]:-}";      do [[ "$v" == "$1" ]] && return; done; FRAMEWORKS+=("$1"); }
add_infra()   { for v in "${INFRASTRUCTURE[@]:-}";  do [[ "$v" == "$1" ]] && return; done; INFRASTRUCTURE+=("$1"); }

# ── Helper: check if package.json has a dependency ───────────────────────────
# Searches both dependencies and devDependencies
pkg_has() {
  local pkg_file="$PROJECT_DIR/package.json"
  [[ -f "$pkg_file" ]] || return 1
  jq -e --arg dep "$1" '
    (.dependencies // {} | has($dep)) or
    (.devDependencies // {} | has($dep))
  ' "$pkg_file" >/dev/null 2>&1
}

# ── 1. Detect package managers ───────────────────────────────────────────────
detect_package_manager() {
  if [[ -f "$PROJECT_DIR/bun.lockb" ]] || [[ -f "$PROJECT_DIR/bun.lock" ]]; then
    PACKAGE_MANAGER="bun"
  elif [[ -f "$PROJECT_DIR/pnpm-lock.yaml" ]]; then
    PACKAGE_MANAGER="pnpm"
  elif [[ -f "$PROJECT_DIR/yarn.lock" ]]; then
    PACKAGE_MANAGER="yarn"
  elif [[ -f "$PROJECT_DIR/package-lock.json" ]]; then
    PACKAGE_MANAGER="npm"
  elif [[ -f "$PROJECT_DIR/package.json" ]]; then
    PACKAGE_MANAGER="npm"
  fi
}

# ── 2. Detect languages ─────────────────────────────────────────────────────
detect_languages() {
  # JavaScript / Node
  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    add_lang "javascript"
    add_lang "node"
  fi

  # TypeScript
  if [[ -f "$PROJECT_DIR/tsconfig.json" ]] || [[ -f "$PROJECT_DIR/tsconfig.base.json" ]]; then
    add_lang "typescript"
  elif pkg_has "typescript"; then
    add_lang "typescript"
  fi

  # Python
  if [[ -f "$PROJECT_DIR/requirements.txt" ]] || \
     [[ -f "$PROJECT_DIR/pyproject.toml" ]] || \
     [[ -f "$PROJECT_DIR/Pipfile" ]] || \
     [[ -f "$PROJECT_DIR/setup.py" ]] || \
     [[ -f "$PROJECT_DIR/setup.cfg" ]]; then
    add_lang "python"
  fi

  # Rust
  if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    add_lang "rust"
  fi

  # Go
  if [[ -f "$PROJECT_DIR/go.mod" ]]; then
    add_lang "go"
  fi

  # PHP
  if [[ -f "$PROJECT_DIR/composer.json" ]]; then
    add_lang "php"
  fi

  # Ruby
  if [[ -f "$PROJECT_DIR/Gemfile" ]]; then
    add_lang "ruby"
  fi

  # Java
  if [[ -f "$PROJECT_DIR/pom.xml" ]] || \
     [[ -f "$PROJECT_DIR/build.gradle" ]] || \
     [[ -f "$PROJECT_DIR/build.gradle.kts" ]]; then
    add_lang "java"
  fi

  # Dart / Flutter
  if [[ -f "$PROJECT_DIR/pubspec.yaml" ]]; then
    add_lang "dart"
  fi
}

# ── 3. Detect frameworks (from package.json) ────────────────────────────────
detect_frameworks() {
  [[ -f "$PROJECT_DIR/package.json" ]] || return 0

  # Frontend frameworks
  if pkg_has "react" || pkg_has "react-dom"; then
    add_fw "react"
    IS_FRONTEND=true
  fi

  if pkg_has "next"; then
    add_fw "nextjs"
    IS_FRONTEND=true
    IS_BACKEND=true
  fi

  if pkg_has "vue"; then
    add_fw "vue"
    IS_FRONTEND=true
  fi

  if pkg_has "nuxt"; then
    add_fw "nuxt"
    IS_FRONTEND=true
    IS_BACKEND=true
  fi

  if pkg_has "svelte" || pkg_has "@sveltejs/kit"; then
    add_fw "svelte"
    IS_FRONTEND=true
  fi

  if pkg_has "@angular/core"; then
    add_fw "angular"
    IS_FRONTEND=true
  fi

  if pkg_has "astro"; then
    add_fw "astro"
    IS_FRONTEND=true
  fi

  # Backend frameworks
  if pkg_has "express"; then
    add_fw "express"
    IS_BACKEND=true
  fi

  if pkg_has "fastify"; then
    add_fw "fastify"
    IS_BACKEND=true
  fi

  if pkg_has "hono"; then
    add_fw "hono"
    IS_BACKEND=true
  fi

  if pkg_has "@nestjs/core"; then
    add_fw "nestjs"
    IS_BACKEND=true
  fi

  # CSS / UI
  if pkg_has "tailwindcss"; then
    add_fw "tailwind"
    IS_FRONTEND=true
  fi

  # shadcn detection: check for components.json (shadcn config) or the package
  if [[ -f "$PROJECT_DIR/components.json" ]] || pkg_has "shadcn-ui" || pkg_has "@shadcn/ui"; then
    add_fw "shadcn"
    IS_FRONTEND=true
  fi

  # ORM / Database
  if pkg_has "prisma" || pkg_has "@prisma/client"; then
    add_fw "prisma"
    IS_BACKEND=true
  fi

  if pkg_has "drizzle-orm"; then
    add_fw "drizzle"
    IS_BACKEND=true
  fi

  if pkg_has "@supabase/supabase-js"; then
    add_fw "supabase"
    IS_BACKEND=true
  fi

  # Payments
  if pkg_has "stripe" || pkg_has "@stripe/stripe-js"; then
    add_fw "stripe"
  fi

  # Testing
  if pkg_has "playwright" || pkg_has "@playwright/test"; then
    add_fw "playwright"
  fi

  if pkg_has "vitest"; then
    add_fw "vitest"
  fi

  if pkg_has "jest"; then
    add_fw "jest"
  fi

  # Flutter (from pubspec.yaml, not package.json)
  if [[ -f "$PROJECT_DIR/pubspec.yaml" ]]; then
    if grep -q "flutter:" "$PROJECT_DIR/pubspec.yaml" 2>/dev/null; then
      add_fw "flutter"
      IS_FRONTEND=true
    fi
  fi
}

# ── 4. Detect infrastructure ────────────────────────────────────────────────
detect_infrastructure() {
  # Docker
  if [[ -f "$PROJECT_DIR/Dockerfile" ]] || \
     [[ -f "$PROJECT_DIR/docker-compose.yml" ]] || \
     [[ -f "$PROJECT_DIR/docker-compose.yaml" ]] || \
     [[ -f "$PROJECT_DIR/.dockerignore" ]]; then
    add_infra "docker"
  fi

  # Kubernetes
  if [[ -d "$PROJECT_DIR/k8s" ]] || [[ -d "$PROJECT_DIR/kubernetes" ]]; then
    add_infra "kubernetes"
  else
    # Check for k8s manifests (kind: Deployment, kind: Service, etc.)
    local k8s_found=false
    for f in "$PROJECT_DIR"/*.yaml "$PROJECT_DIR"/*.yml; do
      [[ -f "$f" ]] || continue
      if grep -qE "^kind:\s*(Deployment|Service|Ingress|ConfigMap|StatefulSet|DaemonSet)" "$f" 2>/dev/null; then
        k8s_found=true
        break
      fi
    done
    [[ "$k8s_found" == true ]] && add_infra "kubernetes"
  fi

  # Terraform
  if compgen -G "$PROJECT_DIR/*.tf" >/dev/null 2>&1 || [[ -d "$PROJECT_DIR/terraform" ]]; then
    add_infra "terraform"
  fi

  # GitHub Actions
  if [[ -d "$PROJECT_DIR/.github/workflows" ]]; then
    add_infra "github-actions"
  fi

  # Vercel
  if [[ -f "$PROJECT_DIR/vercel.json" ]] || [[ -f "$PROJECT_DIR/.vercel" ]]; then
    add_infra "vercel"
  fi

  # Cloudflare
  if [[ -f "$PROJECT_DIR/wrangler.toml" ]] || [[ -f "$PROJECT_DIR/wrangler.jsonc" ]]; then
    add_infra "cloudflare"
  fi

  # CI/CD
  if [[ -f "$PROJECT_DIR/.gitlab-ci.yml" ]]; then
    add_infra "gitlab-ci"
  fi

  if [[ -f "$PROJECT_DIR/.circleci/config.yml" ]]; then
    add_infra "circleci"
  fi
}

# ── Run all detections ───────────────────────────────────────────────────────
detect_package_manager
detect_languages
detect_frameworks
detect_infrastructure

# ── Determine frontend/backend/fullstack ─────────────────────────────────────
# Additional heuristics if not already set
if [[ "$IS_FRONTEND" == false ]]; then
  # Check for common frontend dirs
  if [[ -d "$PROJECT_DIR/src/components" ]] || \
     [[ -d "$PROJECT_DIR/src/pages" ]] || \
     [[ -d "$PROJECT_DIR/src/app" ]] || \
     [[ -d "$PROJECT_DIR/public" ]]; then
    IS_FRONTEND=true
  fi
fi

if [[ "$IS_BACKEND" == false ]]; then
  # Check for common backend indicators
  if [[ -d "$PROJECT_DIR/src/api" ]] || \
     [[ -d "$PROJECT_DIR/src/routes" ]] || \
     [[ -d "$PROJECT_DIR/src/controllers" ]] || \
     [[ -d "$PROJECT_DIR/src/models" ]] || \
     [[ -f "$PROJECT_DIR/server.js" ]] || \
     [[ -f "$PROJECT_DIR/server.ts" ]] || \
     [[ -f "$PROJECT_DIR/app.py" ]] || \
     [[ -f "$PROJECT_DIR/main.go" ]]; then
    IS_BACKEND=true
  fi
fi

IS_FULLSTACK=false
if [[ "$IS_FRONTEND" == true ]] && [[ "$IS_BACKEND" == true ]]; then
  IS_FULLSTACK=true
fi

# ── Build JSON output ────────────────────────────────────────────────────────
to_json_array() {
  local arr=("$@")
  if [[ ${#arr[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi
  # Filter out empty strings, then build JSON array
  local filtered
  filtered=$(printf '%s\n' "${arr[@]}" | grep -v '^$' || true)
  if [[ -z "$filtered" ]]; then
    echo "[]"
    return
  fi
  echo "$filtered" | jq -R . | jq -s '.'
}

LANG_JSON=$(to_json_array "${LANGUAGES[@]:-}")
FW_JSON=$(to_json_array "${FRAMEWORKS[@]:-}")
INFRA_JSON=$(to_json_array "${INFRASTRUCTURE[@]:-}")

jq -n \
  --argjson languages "$LANG_JSON" \
  --argjson frameworks "$FW_JSON" \
  --argjson infrastructure "$INFRA_JSON" \
  --arg packageManager "$PACKAGE_MANAGER" \
  --argjson isFrontend "$IS_FRONTEND" \
  --argjson isBackend "$IS_BACKEND" \
  --argjson isFullstack "$IS_FULLSTACK" \
  '{
    languages: $languages,
    frameworks: $frameworks,
    infrastructure: $infrastructure,
    packageManager: $packageManager,
    isFrontend: $isFrontend,
    isBackend: $isBackend,
    isFullstack: $isFullstack
  }'
