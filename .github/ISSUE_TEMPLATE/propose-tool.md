---
name: Propose a tool
about: Suggest a new tool for the macOS setup
title: "feat: add [tool name]"
labels: tool-proposal
assignees: ""
---

## Tool proposal

Please fill in all fields. The fields map directly to the `manifests/tools.yaml` schema — a complete proposal moves faster through review.

---

### Basic information

**Tool name:**
<!-- Display name, e.g. "Starship" -->

**ID (kebab-case):**
<!-- Unique identifier, e.g. "starship" -->

**Category:**
<!-- apple | shell | node | python | containers | ai | editors | data | media | security | automation -->

**Installation source:**
<!-- brew | cask | npm | npx | mas | curl | uv | ollama | builtin | manual -->

**Package / formula name (ref):**
<!-- e.g. "starship", "visual-studio-code", "@scope/pkg-name" -->

**Setup level:**
<!-- 0 = always | 1 = main stack | 2 = extended | 3 = optional/specialized -->

---

### Rationale

**Why does this tool belong in the setup?**
<!-- One sentence: what problem does it solve that no existing tool solves? -->

**Which alternative was evaluated and why was it rejected?**
<!-- Which other tools were considered? -->

**Does it replace an existing tool?**
<!-- If yes: which one? (ID from tools.yaml) -->

---

### Version information

**Current version:**
<!-- e.g. "1.18.0" -->

**Version check method:**
<!-- brew | npm | github-release | mas | ollama | manual -->

**Check reference (check_ref):**
<!-- e.g. "starship/starship" for GitHub releases, "starship" for brew -->

---

### Checklist

- [ ] The tool solves a real problem in the setup
- [ ] It is not a duplicate of an already active tool
- [ ] It is publicly available (no private package)
- [ ] No personal data in this issue

---

*After adding to `tools.yaml` as `candidate`:*
```bash
automation/bin/sunset adopt <id>
```
