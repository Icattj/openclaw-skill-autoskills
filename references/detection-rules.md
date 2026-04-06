# Detection Rules Reference

How `detect.sh` identifies technologies in a project, and how to extend it.

## Detection Methods

### 1. File Presence Detection

The simplest method — check if a file exists in the project root.

| File | Detects |
|------|---------|
| `package.json` | JavaScript, Node.js |
| `tsconfig.json` | TypeScript |
| `requirements.txt` | Python |
| `pyproject.toml` | Python |
| `Pipfile` | Python |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `composer.json` | PHP |
| `Gemfile` | Ruby |
| `pom.xml` | Java |
| `build.gradle` | Java |
| `pubspec.yaml` | Dart/Flutter |
| `Dockerfile` | Docker |
| `docker-compose.yml` | Docker |
| `vercel.json` | Vercel |
| `wrangler.toml` | Cloudflare |
| `components.json` | shadcn/ui |

### 2. Dependency Detection (package.json)

For JavaScript/TypeScript projects, `detect.sh` reads `package.json` and checks both `dependencies` and `devDependencies` using `jq`:

```bash
# Check if a package exists in package.json
pkg_has() {
  jq -e --arg dep "$1" '
    (.dependencies // {} | has($dep)) or
    (.devDependencies // {} | has($dep))
  ' "$PROJECT_DIR/package.json" >/dev/null 2>&1
}
```

**Dependency → Framework mapping:**

| Package | Framework |
|---------|-----------|
| `react` / `react-dom` | react |
| `next` | nextjs |
| `vue` | vue |
| `nuxt` | nuxt |
| `svelte` / `@sveltejs/kit` | svelte |
| `@angular/core` | angular |
| `astro` | astro |
| `express` | express |
| `fastify` | fastify |
| `hono` | hono |
| `@nestjs/core` | nestjs |
| `tailwindcss` | tailwind |
| `prisma` / `@prisma/client` | prisma |
| `drizzle-orm` | drizzle |
| `@supabase/supabase-js` | supabase |
| `stripe` / `@stripe/stripe-js` | stripe |
| `playwright` / `@playwright/test` | playwright |
| `vitest` | vitest |
| `jest` | jest |

### 3. Directory Detection

Some technologies are detected by directory structure:

| Directory | Detects |
|-----------|---------|
| `.github/workflows/` | GitHub Actions |
| `k8s/` or `kubernetes/` | Kubernetes |
| `terraform/` | Terraform |
| `src/components/` | Frontend (heuristic) |
| `src/api/` or `src/routes/` | Backend (heuristic) |

### 4. Lock File Detection (Package Managers)

| Lock File | Package Manager |
|-----------|----------------|
| `bun.lockb` / `bun.lock` | bun |
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| `package-lock.json` | npm |

Priority order: bun > pnpm > yarn > npm (first match wins).

### 5. Content Detection

Some technologies require reading file contents:

- **Kubernetes:** YAML files checked for `kind: Deployment|Service|Ingress|...`
- **Terraform:** Glob check for `*.tf` files
- **Flutter:** `pubspec.yaml` checked for `flutter:` key

## Frontend/Backend Classification

### Classified as Frontend
- React, Vue, Svelte, Angular, Astro frameworks
- Tailwind, shadcn detected
- `src/components/`, `src/pages/`, `public/` directories exist

### Classified as Backend
- Express, Fastify, Hono, NestJS, Next.js, Nuxt frameworks
- Prisma, Drizzle, Supabase detected
- `src/api/`, `src/routes/`, `src/controllers/`, `server.js` exist
- Python (`app.py`), Go (`main.go`)

### Fullstack
`isFrontend && isBackend` both true.

## Adding New Detection Rules

### Step 1: Add to detect.sh

For a **file-based** detection:
```bash
# In detect_languages() or detect_frameworks() or detect_infrastructure()
if [[ -f "$PROJECT_DIR/your-config-file" ]]; then
  add_fw "your-tech"    # or add_lang / add_infra
  IS_BACKEND=true       # if applicable
fi
```

For a **dependency-based** detection:
```bash
# In detect_frameworks()
if pkg_has "your-package-name"; then
  add_fw "your-tech"
  IS_FRONTEND=true  # or IS_BACKEND, or both
fi
```

### Step 2: Add to skills-map.json

Add a new entry under `technologies`:
```json
{
  "technologies": {
    "your-tech": {
      "openclaw": ["skill-name-if-exists"],
      "clawhub": ["clawhub-skill-name"],
      "external": ["github-owner/repo/skill-name"]
    }
  }
}
```

### Step 3: Add combos (optional)

If a combination of technologies warrants a specific skill:
```json
{
  "combos": {
    "your-tech+other-tech": {
      "openclaw": [],
      "clawhub": [],
      "external": ["owner/repo/combo-skill"]
    }
  }
}
```

## Output Format

Detection output:
```json
{
  "languages": ["javascript", "typescript"],
  "frameworks": ["nextjs", "tailwind", "prisma"],
  "infrastructure": ["docker", "github-actions"],
  "packageManager": "pnpm",
  "isFrontend": true,
  "isBackend": true,
  "isFullstack": true
}
```

All arrays may be empty. `packageManager` is empty string if no JS package manager detected.
