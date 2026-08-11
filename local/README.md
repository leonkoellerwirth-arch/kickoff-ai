# local/ — Maschinenspezifische Daten

Dieses Verzeichnis ist **gitignoriert** und enthält maschinenspezifische Daten,
die nicht veröffentlicht werden:

- `doctor-report.md` — Ausgabe von `./doctor.sh --report`
- Persönliche Override-Hinweise
- Temporäre Analyse-Ergebnisse

## Persönliche Konfiguration

Maschinenspezifische Shell-Einstellungen gehören in:

- `~/.zshrc.local` — Shell-Overrides (Tokens, `CLAUDE_CODE_SUBAGENT_MODEL`, private Aliase)
- `~/.zprofile.local` — Login-Shell-Overrides
- `~/.gitconfig.local` — Git-Identität und SSH-Signierung

Diese Dateien werden von `config/zshrc` bzw. `config/gitconfig` automatisch
geladen, falls vorhanden.
