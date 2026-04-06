---
name: autoskills
description: Auto-detect project tech stack and recommend/install matching AI agent skills. Scans package.json, config files, and project structure to find frameworks, languages, and infrastructure. Maps detections to OpenClaw skills, clawhub packages, and external skill sources. Use when starting work on a new project, onboarding to a codebase, or checking if better skills are available.
---

# autoskills

Auto-detect a project's tech stack and recommend matching AI agent skills for OpenClaw.

Inspired by [midudev/autoskills](https://github.com/midudev/autoskills), adapted for the OpenClaw ecosystem.

## Quick Start

### Scan a project directory

```bash
# Detect tech stack
bash ~/.openclaw/workspace/skills/autoskills/scripts/detect.sh /path/to/project

# Detect + get recommendations in one step
bash ~/.openclaw/workspace/skills/autoskills/scripts/recommend.sh --detect /path/to/project

# Or pipe them
bash ~/.openclaw/workspace/skills/autoskills/scripts/detect.sh /path/to/project \
  | bash ~/.openclaw/workspace/skills/autoskills/scripts/recommend.sh
```

### Install a recommended skill

```bash
# From ClawHub
bash ~/.openclaw/workspace/skills/autoskills/scripts/install.sh nextjs-best-practices --from clawhub

# From skills.sh (shows instructions)
bash ~/.openclaw/workspace/skills/autoskills/scripts/install.sh vercel-labs/next-skills/next-best-practices --from skills.sh
```

## How It Works

### 1. Detection (`detect.sh`)

Scans a project directory for:

- **Languages** — JavaScript, TypeScript, Python, Rust, Go, PHP, Ruby, Java, Dart
- **Frameworks** — React, Next.js, Vue, Nuxt, Svelte, Angular, Astro, Express, Fastify, Hono, NestJS, Tailwind, shadcn/ui, Prisma, Drizzle, Supabase, Stripe, Playwright, Vitest, Jest, Flutter
- **Infrastructure** — Docker, Kubernetes, Terraform, GitHub Actions, Vercel, Cloudflare, GitLab CI, CircleCI
- **Package Manager** — npm, yarn, pnpm, bun

Detection methods:
1. **File presence** — `Dockerfile`, `tsconfig.json`, `Cargo.toml`, etc.
2. **package.json dependencies** — reads both `dependencies` and `devDependencies`
3. **Directory structure** — `.github/workflows/`, `k8s/`, `src/components/`
4. **File content** — YAML files checked for Kubernetes manifests, `pubspec.yaml` for Flutter

Also classifies the project as frontend, backend, or fullstack based on detected frameworks and directory heuristics.

### 2. Recommendation (`recommend.sh`)

Maps each detected technology to three tiers of skills:

| Tier | Source | Description |
|------|--------|-------------|
| **installed** | OpenClaw workspace | Skills already in `~/.openclaw/workspace/skills/` |
| **available** | ClawHub | Installable via `clawhub install <name>` |
| **external** | skills.sh / GitHub | External skill files that can be imported |

Also checks **combo detections** — when multiple techs are present together, recommends specialized combo skills (e.g., `nextjs + tailwind + shadcn` triggers tailwind-v4-shadcn recommendations).

### 3. Installation (`install.sh`)

Installs skills from supported sources:
- **clawhub** — Uses the `clawhub` CLI (falls back to `npx clawhub`)
- **skills.sh** — Prints instructions to manually import or use the `skill-absorber` skill

## The Skills Map

All mappings live in `scripts/skills-map.json`. Structure:

```json
{
  "technologies": {
    "tech-name": {
      "openclaw": ["local-skill-name"],
      "clawhub": ["clawhub-package-name"],
      "external": ["github-owner/repo/skill-path"]
    }
  },
  "combos": {
    "tech1+tech2+tech3": {
      "openclaw": [],
      "clawhub": [],
      "external": ["owner/repo/combo-skill"]
    }
  }
}
```

### Adding New Mappings

1. Edit `scripts/skills-map.json`
2. Add your tech under `technologies` with the three skill arrays
3. Optionally add combo entries under `combos` (techs joined with `+`)
4. If your tech needs new detection logic, edit `scripts/detect.sh` — see `references/detection-rules.md` for details

### Currently Mapped Technologies

**Languages:** javascript, typescript, python, rust, go, php, ruby, java, dart  
**Frameworks:** react, nextjs, vue, nuxt, svelte, angular, astro, express, fastify, hono, nestjs, tailwind, shadcn, prisma, drizzle, supabase, stripe, playwright, vitest, jest, flutter  
**Infrastructure:** docker, kubernetes, terraform, github-actions, vercel, cloudflare  
**Combos:** nextjs+tailwind+shadcn, node+express, react+tailwind, vue+nuxt, prisma+supabase, typescript+vitest

## Example Output

### Detection

```json
{
  "languages": ["javascript", "typescript", "node"],
  "frameworks": ["nextjs", "tailwind", "shadcn", "prisma"],
  "infrastructure": ["docker", "github-actions", "vercel"],
  "packageManager": "pnpm",
  "isFrontend": true,
  "isBackend": true,
  "isFullstack": true
}
```

### Recommendations

```json
{
  "detection": { "..." },
  "recommendations": {
    "installed": [
      {"skill": "ui-ux-pro-max", "reason": "Detected nextjs"},
      {"skill": "dev-workflow", "reason": "Detected typescript"},
      {"skill": "github-enhanced", "reason": "Detected github-actions"}
    ],
    "available": [],
    "external": [
      {"source": "skills.sh", "skill": "vercel-labs/next-skills/next-best-practices", "reason": "Detected nextjs"},
      {"source": "skills.sh", "skill": "prisma/skills/prisma-database-setup", "reason": "Detected prisma"},
      {"source": "skills.sh", "skill": "secondsky/claude-skills/tailwind-v4-shadcn", "reason": "Combo detected: nextjs + tailwind + shadcn"}
    ]
  },
  "summary": {
    "totalInstalled": 3,
    "totalAvailable": 0,
    "totalExternal": 3
  }
}
```

## Agent Integration

When an agent loads this skill, it should:

1. Run detection on the project directory the user is working on
2. Present the recommendations in a clear format
3. Offer to install available/external skills
4. Note which installed skills are already relevant

Typical agent prompt flow:
```
User: "Scan this project for me"
Agent: runs detect.sh → recommend.sh
Agent: "Found Next.js + Tailwind + Prisma project. You already have ui-ux-pro-max.
        I recommend installing prisma-database-setup from skills.sh. Want me to set it up?"
```

## Requirements

- **bash** 4+ (available on all modern Linux/macOS)
- **jq** (JSON processor — pre-installed on most VPS, `apt install jq` if missing)
- **clawhub** CLI (optional, only for ClawHub installs)

No Node.js required for core detection and recommendation.

## File Structure

```
skills/autoskills/
├── SKILL.md                      ← This file
├── scripts/
│   ├── detect.sh                 ← Tech stack detection
│   ├── recommend.sh              ← Map to skill recommendations
│   ├── install.sh                ← Install skills from sources
│   └── skills-map.json           ← Technology → skills mapping
└── references/
    └── detection-rules.md        ← Detailed detection documentation
```
