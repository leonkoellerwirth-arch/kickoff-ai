# manifests/ — Tool Registry

<!-- Technical reference. Maintained in English only; no separate German version. -->

This directory contains the **single source of truth** for all tools in this macOS setup.

## Files

| File | Purpose |
|---|---|
| `tools.yaml` | Complete registry of all tools (schema: `schema.md`) |
| `schema.md` | Field documentation and allowed values |
| `STATE.json` | Machine-readable state of the last check (updated automatically) |
| `README.md` | This file |

---

## Relationship to Implementation Lists

The registry (`tools.yaml`) is the **truth**. The implementation lists are the **execution**:

| Implementation list | Contains | Verified by |
|---|---|---|
| `Brewfile` | Core formulae and casks (levels 0–1) | `up2date --consistency` |
| `Brewfile.optional` | Optional formulae (levels 2–3) | `up2date --consistency` |
| `Brewfile.automation` | Automation dependencies (yq, etc.) | `up2date --consistency` |
| `automation/manifests/ollama-models.txt` | Desired Ollama models | `up2date --consistency` |
| `config/vscode-extensions.txt` | VS Code extensions | `up2date --consistency` |

**Invariant:** A tool with `status: active` in the registry **must** appear in the
matching implementation list. A tool with `status: sunset` **must not** appear in any
implementation list (CI fails otherwise).

---

## Adding a Tool

1. **Add an entry in `tools.yaml`** (all fields required; `id` must be unique and kebab-case):

   ```yaml
   - id: my-tool
     name: My Tool
     category: shell
     source: brew
     ref: my-tool
     level: 2
     status: candidate      # Evaluate first, then set to active
     version_seen: "1.0.0"
     version_check: brew
     check_ref: my-tool
     why: "Why this tool and not an alternative?"
     added: 2026-08-11
     reviewed: 2026-08-11
     sunset: null
     replaced_by: null
   ```

2. **Update the implementation list** (Brewfile, Brewfile.optional, or ollama-models.txt):

   ```
   brew "my-tool"    # Brief rationale
   ```

3. **Confirm status** (when evaluation is successful):

   ```bash
   automation/bin/sunset adopt my-tool
   ```

4. **Check consistency:**

   ```bash
   automation/bin/up2date --consistency --offline
   ```

---

## Retiring a Tool

Retirement is a deliberate three-phase process. The registry documents the decision;
a separate script handles uninstallation.

### Phase 1: Propose Retirement

```bash
automation/bin/sunset propose <id> --reason "Reason the tool is no longer needed"
```

Effect:
- `status` changes from `active` → `deprecated`
- `sunset` date is set to today + 90 days
- Entry added to `CHANGELOG.md` (section `Unreleased`)

### Phase 2: Wait Out the Grace Period (90 Days)

During the grace period:
- The tool remains installed and functional
- Weekly `up2date` runs remind via GitHub issue of due sunsets
- The entry appears in `sunset list --due` when the date is reached

### Phase 3: Confirm Sunset (after grace period)

```bash
automation/bin/sunset confirm <id>
```

Effect:
- `status` changes from `deprecated` → `sunset`
- Tool **must not** appear in any implementation list (CI fails otherwise)
- The actual uninstallation is handled by `scripts/90-cleanup-legacy.sh` or the
  relevant module script

### Reverting a Sunset

```bash
automation/bin/sunset revive <id> --reason "Reason for reactivation"
```

### Overview of Due Sunsets

```bash
automation/bin/sunset list --due
automation/bin/sunset list --status deprecated
```

---

## Removing an Entry from the Registry

An entry with `status: sunset` is only removed from `tools.yaml` once the software
has actually been uninstalled. After that:

1. Delete the line from `tools.yaml`.
2. Add a line to `CHANGELOG.md` (section `Unreleased`, category `Removed`).
3. Open a PR.

---

## Integration with `scripts/90-cleanup-legacy.sh`

The script currently removes hardcoded legacy cruft: OpenClaw and the orphaned
MariaDB LaunchAgent. Both tools are documented as `status: sunset` in `tools.yaml`.

**Planned integration:** In a future version `90-cleanup-legacy.sh` will read the
sunset entries from `tools.yaml` dynamically instead of hard-coding them. The registry
will then be the single source of truth for what needs to be cleaned up. This
integration is deliberately not implemented yet — uninstallation must always remain
a human decision.

---

## Understanding `STATE.json`

`STATE.json` is updated by `.github/workflows/up2date.yml` after every check and
contains:

```json
{
  "last_check": "2026-08-11T10:00:00Z",
  "checked_count": 42,
  "update_available": 3,
  "sunset_candidate": 1,
  "adoption_candidate": 0,
  "review_due": 2,
  "drift_found": false
}
```

This file belongs in the repository (it is status information, not secrets) and is
intended for dashboard integrations.
