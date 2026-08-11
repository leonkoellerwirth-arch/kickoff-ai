# Schema — manifests/tools.yaml

<!-- Technical reference. Maintained in English only; no separate German version. -->

Every tool in the registry is a YAML list entry with the following required fields.

---

## Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | Unique identifier, kebab-case, no spaces |
| `name` | string | yes | Display name (may contain spaces and special characters) |
| `category` | string | yes | Functional category (see below) |
| `source` | string | yes | Installation source (see below) |
| `ref` | string | yes | Package name, formula name, app ID, or URL |
| `level` | integer | yes | Bootstrap level 0–3 (see below) |
| `status` | string | yes | Lifecycle status (see below) |
| `version_seen` | string | yes | Last observed version from inventory; `""` when unknown |
| `version_check` | string | yes | Method for checking upstream versions (see below) |
| `check_ref` | string | yes | Parameter for the check method (e.g. `owner/repo`); `""` if not applicable |
| `why` | string | yes | One-liner: why this tool is included |
| `added` | date | yes | Date first added to the registry (YYYY-MM-DD) |
| `reviewed` | date | yes | Date of most recent review (YYYY-MM-DD) |
| `sunset` | date\|null | yes | Planned removal date (YYYY-MM-DD); `null` for active tools |
| `replaced_by` | string\|null | yes | `id` of the successor tool; `null` if there is no successor |

---

## Allowed Values

### `category`

| Value | Meaning |
|---|---|
| `apple` | Apple platform tools (Xcode, CocoaPods, Swift-specific) |
| `shell` | Shell tools, runtimes, general CLI tools |
| `node` | Node.js ecosystem (nvm, pnpm, npm packages, JS runtimes) |
| `python` | Python ecosystem (uv, pipx, conda, Python CLIs) |
| `containers` | Container technology (Docker, Kubernetes clients) |
| `ai` | AI/ML tools (AI CLIs, local models, ML libraries) |
| `editors` | Editors and IDEs (VS Code, iTerm2, Ghostty) |
| `data` | Database and JVM tools (PostgreSQL, MySQL, Java, Maven) |
| `media` | Media and document processing (ffmpeg, OCR, PDF) |
| `security` | Security and pen-test tools (gitleaks, nmap, sqlmap) |
| `automation` | Desktop automation and workflow tools (Raycast, LaunchAgents) |

### `source`

| Value | Meaning | Example `ref` |
|---|---|---|
| `brew` | Homebrew formula | `git`, `postgresql@17` |
| `cask` | Homebrew cask (GUI app) | `visual-studio-code`, `docker` |
| `npm` | npm package (global) | `@openai/codex`, `pnpm` |
| `npx` | npx-executable package (not installed, run on demand) | `create-react-app` |
| `mas` | Mac App Store | `497799835` (Xcode) |
| `curl` | Direct installation via curl/script | URL or description |
| `uv` | uv tool installation (`uv tool install`) | `nano-pdf` |
| `ollama` | Ollama model (`ollama pull`) | `llama3.2`, `deepseek-r1:14b` |
| `builtin` | Integrated into macOS or another tool | name of the parent tool |
| `manual` | Manual installation, no package manager | description or path |

### `level`

| Value | When installed | Typical tools |
|---|---|---|
| `0` | Always, first | git, Homebrew, shell config, Xcode CLT |
| `1` | Main development stack | Node, Python, Docker, AI CLIs, editors |
| `2` | Extended runtimes and services | databases, JVM, conda, media tools |
| `3` | Specialized and optional tools | pen-test tools, ML libraries, niche CLIs |

### `status`

```
candidate ──► active ──► deprecated ──► sunset ──► (entry removed)
    └──────── (dropped, needs `sunset adopt`)        ▲
                                                      └── 90-day grace period
```

| Value | Meaning |
|---|---|
| `candidate` | Newly discovered or under evaluation; `why` explains the assessment need |
| `active` | Actively used and maintained; present in the implementation lists |
| `deprecated` | Scheduled for removal; `sunset` date set (today + 90 days) |
| `sunset` | Removal decided; `sunset` date is reached or passed |

**Rules:**
- `sunset` date: required for `deprecated` and `sunset`, must be `null` for `candidate` and `active`.
- A `sunset` entry remains in the registry until `scripts/90-cleanup-legacy.sh` or the
  equivalent script has actually removed the software. The line is then deleted from the YAML
  and entered in the CHANGELOG.

### `version_check`

| Value | Method | Requires |
|---|---|---|
| `brew` | `brew info --json=v2 <check_ref>` | Homebrew |
| `npm` | `npm view <check_ref> version` | Node.js/npm |
| `github-release` | GitHub Releases API (`/repos/<check_ref>/releases/latest`) | network; `GITHUB_TOKEN` optional |
| `mas` | `mas outdated` | mas installed |
| `ollama` | Ollama Registry (best effort) | Ollama |
| `manual` | Not automatically checkable | — |

---

## Validation Rules (checked by `validate.yml`)

1. Every `id` is unique in the entire document.
2. `category` is one of the 11 allowed values.
3. `source` is one of the 10 allowed values.
4. `level` is 0, 1, 2, or 3.
5. `status` is one of the 4 allowed values.
6. `version_check` is one of the 6 allowed values.
7. `added` and `reviewed` are valid dates in YYYY-MM-DD format.
8. `sunset` is either `null` or a valid date in YYYY-MM-DD format.
9. `sunset` must be `null` when `status` = `candidate` or `active`.
10. `sunset` must be set when `status` = `deprecated` or `sunset`.
11. `replaced_by` is either `null` or an `id` that exists in the same document.
12. `why` must not be empty.
