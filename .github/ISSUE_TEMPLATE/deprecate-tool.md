---
name: Deprecate a tool
about: Propose removing an existing tool from the setup
title: "deprecate: [tool name]"
labels: tool-deprecation
assignees: ""
---

## Tool deprecation

This proposal starts the documented sunset window (90 days) for a tool.
After acceptance, `automation/bin/sunset propose` will be run.

---

### Tool

**Tool ID (from tools.yaml):**
<!-- e.g. "openclaw-npm" -->

**Current status:**
<!-- candidate | active -->

---

### Rationale

**Why should this tool be removed?**
<!-- e.g. "No longer actively used", "Upstream unmaintained", "Better alternative available" -->

**Replacement tool (if any):**
<!-- ID of the replacement from tools.yaml, or "none" -->

**Consequences of removal:**
<!-- What needs to be updated? Scripts, workflows, aliases? -->

---

### Upstream status

**Is the tool still actively maintained upstream?**
<!-- Last release date, repository status -->

**Are there upstream deprecation signals?**
<!-- e.g. "GitHub repository archived", "npm deprecated flag set" -->

---

### Checklist

- [ ] The tool is genuinely no longer in use
- [ ] No running process or service depends on it
- [ ] Dependent scripts and configuration are identified
- [ ] A replacement (or conscious decision not to replace) is documented

---

### Next steps (after acceptance)

```bash
# Propose sunset (sets status: deprecated, date: today + 90 days)
automation/bin/sunset propose <id> --reason "..." [--replaced-by <replacement-id>]

# After 90 days: confirm sunset
automation/bin/sunset confirm <id>

# Remove the software
./scripts/90-cleanup-legacy.sh  # or the relevant module script
```

**Important:** Status changes are always a human decision.
This issue informs — it does not remove any software.
