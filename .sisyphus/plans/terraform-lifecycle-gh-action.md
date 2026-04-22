# Plan: Terraform Lifecycle GitHub Action Overhaul

## Repository Analysis

### Structure
```
terraform-sandbox/
├── environments/
│   ├── dev/
│   │   ├── random_pet_dev/     # main.tf, providers.tf, variables.tf, outputs.tf
│   │   └── random_password_dev/
│   └── prod/
│       ├── random_pet/
│       └── random_password/
└── .github/workflows/pipeline.yaml
```

- All modules use **random provider only** (no cloud credentials needed)
- All `providers.tf` files contain `terraform { cloud { ... } }` blocks (Terraform Cloud) — must be removed
- State is stored **locally**
- Existing workflow has several issues detailed below

---

## Problems with Current Workflow

| # | Issue |
|---|-------|
| 1 | `paths` filter points to `environments/terraform/**` — wrong path; actual modules are under `environments/dev/` and `environments/prod/` |
| 2 | `BASE_PATH` in the detect step also references the wrong path |
| 3 | Terraform Cloud credentials (`TF_API_TOKEN`, `cli_config_credentials_*`) still in use |
| 4 | `terraform plan` has no `-out` flag; apply runs fresh plan instead of using saved plan |
| 5 | Format auto-fix exits with code 1 — causes the workflow to show as "failed" rather than cleanly stopping |
| 6 | Matrix module depth uses `cut -d/ -f1-5` which may not align with actual folder depth |
| 7 | PAT token used for fmt auto-commit — security concern |

---

## Implementation Plan

### 1. Remove Terraform Cloud from all `providers.tf` files

Replace every `terraform { cloud { ... } ... }` block with a plain `terraform { required_providers { ... } }` block across all 4 modules:
- `environments/dev/random_pet_dev/providers.tf`
- `environments/dev/random_password_dev/providers.tf`
- `environments/prod/random_pet/providers.tf`
- `environments/prod/random_password/providers.tf`

Local state will be used automatically when no backend is configured.

> ⚠️ Note: Local state means `.terraform/` and `*.tfstate` files will be created in the runner's workspace at runtime. These are ephemeral on GitHub Actions runners. If persistence is ever needed later, a backend (S3, GCS, etc.) can be added.

---

### 2. Rewrite `.github/workflows/pipeline.yaml`

#### Triggers
```yaml
on:
  pull_request:
    branches: [main]
    paths:
      - "environments/**/*.tf"
  push:
    branches: [main]
    paths:
      - "environments/**/*.tf"
```

#### Job 1: `format-and-detect`

**Permissions:** `contents: write` (to push fmt commits), `pull-requests: write` (for PR comments)

**Steps:**
1. Generate a short-lived GitHub App token using `actions/create-github-app-token@v1` with `APP_ID` and `APP_PRIVATE_KEY` secrets
2. Checkout with `fetch-depth: 0` using the generated App token — this ensures the auto-committed fmt commit re-triggers the workflow (commits by `GITHUB_TOKEN` do not re-trigger workflows; App token commits do)
3. Setup Terraform
3. **Detect changed modules** — dynamically find unique parent directories of changed `.tf` files:
   - On PR: `git diff --name-only origin/$BASE_REF HEAD -- 'environments/**'`
   - On push: `git diff --name-only $BEFORE_SHA $SHA -- 'environments/**'`
   - Use `dirname` on each changed `.tf` file path → `sort -u` to deduplicate
   - Only include paths that are actual directories containing `main.tf`
   - Output JSON array for matrix
4. **Terraform fmt** on each changed directory
5. **Auto-commit** using `stefanzweifel/git-auto-commit-action@v5` with the GitHub App token
6. **Exit 0 cleanly** if fmt committed — the new commit re-triggers the workflow naturally

**Key behaviour:** Exit `0` after fmt commit so the job is green. The auto-committed new commit re-triggers a fresh workflow run.

#### Job 2: `terraform` (matrix)

**Condition:** Runs only if `matrix != '[]'` AND no fmt changes were committed

**Matrix:** Each unique changed module directory

**Steps per module:**
1. Checkout
2. Setup Terraform (no cloud credentials, no PAT)
3. `terraform init`
4. `terraform validate`
5. `tfsec` security scan
6. **On PR (`pull_request` event):**
   - `terraform plan -out=tfplan.binary -no-color`
   - `terraform show -no-color tfplan.binary > plan.txt` (convert to human-readable)
   - Post `plan.txt` content as a collapsible PR comment via `actions/github-script`
   - **No artifact upload** — plan file is discarded after comment is posted
7. **On push to main (`push` event):**
   - `terraform plan -out=tfplan.binary -no-color` (fresh plan — safe, accurate, no stale state risk)
   - `terraform apply tfplan.binary -no-color`
   - Find associated PR via `listPullRequestsAssociatedWithCommit`
   - Post apply output + status to that PR as a comment

> **Why re-run plan on merge (not reuse artifact):** Re-planning on merge guarantees the apply uses state that reflects current reality. Stale plans from a PR run could be days old and cause drift or unexpected changes.

---

## File Change Summary

| File | Action |
|------|--------|
| `.github/workflows/pipeline.yaml` | Full rewrite |
| `environments/dev/random_pet_dev/providers.tf` | Remove `cloud {}` block |
| `environments/dev/random_password_dev/providers.tf` | Remove `cloud {}` block |
| `environments/prod/random_pet/providers.tf` | Remove `cloud {}` block |
| `environments/prod/random_password/providers.tf` | Remove `cloud {}` block |

---

## Secrets Required

| Secret | Purpose |
|--------|---------|
| `GITHUB_TOKEN` | Auto-provided by GitHub Actions — used for PR comments |
| `APP_ID` | GitHub App ID — used to generate a short-lived token for fmt auto-commits |
| `APP_PRIVATE_KEY` | GitHub App private key — used alongside `APP_ID` to generate the token |

> `MY_GIT_PAT` and `TF_API_TOKEN` secrets can be deleted from repo settings — no longer needed.

---

## Flow Diagram

```
PR opened/updated
        │
        ▼
format-and-detect job
  ├─ Detect changed .tf dirs → matrix (using dirname + sort -u)
  ├─ terraform fmt on each changed dir
  ├─ If fmt made changes → auto-commit via GITHUB_TOKEN → exit 0
  │       └─ new commit re-triggers full workflow
  └─ If already clean → pass matrix to next job
        │
        ▼
terraform job (matrix: one job per changed module)
  ├─ terraform init
  ├─ terraform validate
  ├─ tfsec scan
  ├─ terraform plan -out=tfplan.binary
  ├─ terraform show → plan.txt
  └─ Post plan.txt as PR comment
        │
       PR approved & merged to main
        │
        ▼
terraform job (matrix: one job per changed module)
  ├─ terraform init
  ├─ terraform plan -out=tfplan.binary  ← fresh plan, no artifact reuse
  ├─ terraform apply tfplan.binary
  └─ Post apply output to PR comment
```
