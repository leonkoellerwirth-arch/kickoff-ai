# Kritische Review des öffentlichen Repositorys

**Stand:** 2026-08-11, `main` auf Commit `5b58a89ce8d1`

**Perspektive:** fremde Person, die das öffentliche Repository erstmals prüft, klont oder den dokumentierten Bootstrap ausführt

**Kurzurteil:** Die Idee ist klar, ungewöhnlich transparent dokumentiert und statisch überwiegend sauber umgesetzt. In der derzeitigen Fassung sollte der öffentliche Ausführungspfad dennoch nicht ohne Vorbehalt empfohlen werden: Ein bestätigter Pfad kann persönliche Git-Daten in eine verfolgte Datei schreiben, zentrale Schutzversprechen zu Currency, Gate, Dry-run und Stufen werden vom Code nicht eingehalten, und schreibberechtigte GitHub-Workflows sind nicht ausreichend gegen Fehler oder Eingabeinjektion abgesichert.

## 1. Verständnis von Vorhaben und Nicht-Zielen

Erst dieses Verständnis bildet den Maßstab der Kritik:

- `kickoff-ai` ist eine öffentliche MIT-„Bridge“ und soll eine reale Apple-Silicon-macOS-Entwicklungsumgebung in vier kumulativen Stufen wiederherstellbar machen. Dazu gehören Installation, Diagnose, Drift-Erkennung und Migration ([BIBLE.md, Z. 8–16](../../BIBLE.md#L8-L16)).
- Das eigentliche Produktversprechen ist nicht die konkrete AI-Werkzeugliste, sondern: „setups rot, this one reports it“. Der Registry-/Currency-Mechanismus soll Drift sichtbar machen, während Installation, Adoption und Retirement menschliche Entscheidungen bleiben ([BIBLE.md, Z. 23–25](../../BIBLE.md#L23-L25), [BIBLE.md, Z. 61–63](../../BIBLE.md#L61-L63)).
- Das Repository verspricht gestufte Installation, einen blockierenden Doctor, eine Registry als „single source of truth“, sichere Wiederholbarkeit, Dry-run sowie einen lokalen Gate mit CI-Parität ([README.md, Z. 20–29](../../README.md#L20-L29), [BIBLE.md, Z. 34–45](../../BIBLE.md#L34-L45)).
- Ausdrückliche Nicht-Ziele sind Byte-Reproduzierbarkeit, Fleet-Management, Intel-/Cross-Platform-Support und bereits bewiesene Mehrmaschinen-Tauglichkeit. Die konkrete Werkzeugauswahl soll angepasst werden ([README.md, Z. 196–202](../../README.md#L196-L202)). Diese bewussten Grenzen werden hier **nicht** als Mängel gewertet.
- Auch `curl | bash` ist eine offen erklärte Risikoentscheidung und kein überraschend entdeckter Defekt ([SECURITY.md, Z. 14–24](../../SECURITY.md#L14-L24)). Bewertet wird, ob die dafür nötigen kompensierenden Kontrollen und die beworbenen Prüfpfade tatsächlich funktionieren.

Das beabsichtigte Ergebnis ist damit verständlich: keine universelle Paketverwaltung, sondern ein öffentlich nachvollziehbares, anpassbares und selbstprüfendes Setup-Gerüst für eine einzelne macOS-Entwicklungsmaschine. Kritik folgt erst ab hier und richtet sich an nachweisbare Abweichungen von diesem Vertrag.

## 2. Methodik und Grenzen

Geprüft wurden die maßgeblichen Verträge (`CONSTITUTION.md`, `BIBLE.md`, neuester `HANDOFF.md`-Eintrag), öffentliche Einstiegs- und Community-Dokumente, sämtliche GitHub-Workflows und Templates, Bootstrap/Prepare/Doctor, Module, Automation, LaunchAgents, Registry und Schema, Migrationswerkzeuge sowie Sicherheits- und Sanitization-Pfade.

Read-only beziehungsweise isoliert ausgeführt wurden:

- Syntaxprüfung aller Shell-Dateien, `shellcheck -S warning`, `plutil` für alle Plists sowie YAML-Parsing: bestanden.
- `prepare.sh --check-only`: erfolgreich und ohne beobachtete Änderung.
- `automation/bin/up2date --consistency --offline`: erfolgreich.
- dieselben Sanitization-, Schema- und Linkprüfungen wie in `validate.yml`: bestanden.
- `gitleaks git --no-banner --redact .`: gesamte vorhandene Historie ohne Fund.
- `scripts/gate.sh`: fehlgeschlagen und ohne vorgeschriebenes Abschlussurteil abgebrochen.
- `bootstrap.sh --level 0 --dry-run --yes`: Exit 0 trotz Doctor-FAIL; zusätzlich erschien eine Corepack-Download-Ankündigung.
- gezielte Reproduktionen in temporären Kopien/HOME-Verzeichnissen für Git-Konfiguration, leere Currency-Ergebnisse, Cask-Versionen und scoped npm-Pakete; dabei wurde weder das echte HOME noch installierte Software verändert.
- read-only GitHub-Abfragen zu Repository-Sichtbarkeit, Schutzregeln, Security-Einstellungen und Workflow-Läufen.

Nicht geprüft wurden ein vollständiger installierender Lauf auf einem frischen Mac, Wiederherstellung aus echten Backups, reale Vault-Secrets, externe Paketquellen auf Kompromittierung, ein schreibender Release-/Currency-Lauf oder Mehrmaschinen-Kompatibilität. GitHub-Einstellungen sind eine Momentaufnahme vom 2026-08-11. Befunde zu Plattformverhalten wurden auf der vorgesehenen macOS-/Bash-3.2-Oberfläche reproduziert; Aussagen über alle zukünftigen macOS-Versionen werden daraus nicht abgeleitet.

## 3. Verifizierte Befunde

### K1 — Kritisch: Git-Identität kann in das öffentliche Repository geschrieben werden

**Behauptung:** Modul 08 verlinkt die globale Git-Konfiguration auf eine verfolgte Datei und schreibt anschließend persönliche Identität sowie einen absoluten lokalen Pfad durch genau diesen Link. Der CI-Sanitizer prüft diese extensionlose Datei nicht.

**Evidenz:** Das Modul setzt `~/.gitconfig` auf `config/gitconfig` ([scripts/08-git-ssh.sh, Z. 36–64](../../scripts/08-git-ssh.sh#L36-L64): „`run ln -sf "$CONFIG_GITCONFIG" "$TARGET_GITCONFIG"`“) und führt danach `git config --global user.name` und `user.email` aus ([scripts/08-git-ssh.sh, Z. 106–113](../../scripts/08-git-ssh.sh#L106-L113)); später schreibt es auch `core.hooksPath` global ([scripts/08-git-ssh.sh, Z. 315–317](../../scripts/08-git-ssh.sh#L315-L317)). Die Vorlage behauptet dagegen, Modul 08 befülle `~/.gitconfig.local` ([config/gitconfig, Z. 153–158](../../config/gitconfig#L153-L158)). `validate.yml` wählt nur bestimmte Erweiterungen und `Brewfile*` aus ([.github/workflows/validate.yml, Z. 133–140](../../.github/workflows/validate.yml#L133-L140)); `config/gitconfig` gehört nicht dazu. Eine isolierte HOME-Reproduktion bestätigte, dass `git config --global` den verlinkten Repository-Inhalt verändert.

**Interpretation:** Nach dem normalen, dokumentierten Setup kann ein späterer Commit Name, E-Mail und lokalen absoluten Hook-Pfad veröffentlichen. Das widerspricht unmittelbar INV-3 und ist bei einem öffentlichen Repository ein konkreter Privacy- und Publication-Risk, nicht nur ein theoretischer Stilfehler.

**Gegenprüfung:** Eine bestehende reguläre `~/.gitconfig` wird vor dem Ersetzen gesichert, und Dry-run verhindert die `git config`-Aufrufe. Das schützt jedoch weder einen normalen Lauf noch den anschließend veränderten Worktree.

**Begrenzte Maßnahme:** Identität und lokale Pfade ausschließlich mit `git config --file "$HOME/.gitconfig.local" …` schreiben; die verfolgte Datei nur als unveränderliche Include-Vorlage behandeln. Einen Temp-HOME-Regressionstest hinzufügen, der nach Modul 08 einen unveränderten Git-Worktree fordert, und alle verfolgten Textdateien in die Sanitization aufnehmen.

### K2 — Kritisch: Das zentrale Currency-System kann abstürzen und Fehler als „aktuell“ melden

**Behauptung:** Der als Differenzierungsmerkmal deklarierte `up2date`-Pfad ist im Nullfund-Fall defekt, liest Cask-Versionen nicht zuverlässig und lässt Upstream-Fehler in CI als leeres, erfolgreiches Ergebnis erscheinen.

**Evidenz:** `_output_results` iteriert auch bei `total=0` über `seq 0 -1` und greift auf nicht gesetzte Arrayelemente zu ([automation/bin/up2date, Z. 431–448](../../automation/bin/up2date#L431-L448)); der JSON-Exitcode hängt danach nur von der Fundzahl, nicht von `errs`, ab ([automation/bin/up2date, Z. 455–465](../../automation/bin/up2date#L455-L465)). Die Brew-Abfrage verkettet Formel- und Cask-`jq` mit `||` ([automation/lib-currency.sh, Z. 220–235](../../automation/lib-currency.sh#L220-L235)); `jq` liefert für eine fehlende Formel ein leeres Ergebnis mit Exit 0, daher wird der Cask-Zweig nicht ausgeführt. Der Wochenworkflow unterdrückt beide Check-Fehler und alle Apply-Fehler mit `|| true` und interpretiert nicht parsebares JSON als null Funde ([.github/workflows/up2date.yml, Z. 84–103](../../.github/workflows/up2date.yml#L84-L103), [.github/workflows/up2date.yml, Z. 110–115](../../.github/workflows/up2date.yml#L110-L115)). In einer isolierten Kopie endete ein leerer Offline-JSON-Lauf mit `RES_CAT[$i]: unbound variable`; eine reale Cask-Metadatenprobe lieferte trotz vorhandener Version leer.

**Interpretation:** „Keine Meldung“ ist nicht unterscheidbar von „Prüfung defekt“. Damit kann das Repository genau die stille Alterung erzeugen, die sein Kernversprechen verhindern soll; ein nachfolgender schreibender Workflow arbeitet dann auf unvalidierter Grundlage.

**Gegenprüfung:** Die reine Registry-Konsistenzprüfung bestand offline. Das beweist die Übereinstimmung ausgewählter Listen, nicht den Upstream-/Nullfund-/Apply-Pfad. Für den neu angelegten Wochenplan lag noch kein aussagekräftiger geplanter End-to-End-Lauf vor.

**Begrenzte Maßnahme:** Nullfund-Schleifen ohne `seq 0 -1` implementieren, Formel/Cask explizit per `jq '// …'` auswählen, Transport-/Parsefehler mit eigenem Exitcode ungleich 0 behandeln und CI nur den dokumentierten Drift-Exitcode tolerieren lassen. Vor Apply muss valides JSON vorliegen; Fixtures für null Funde, Formeln, Casks, Rate-Limit und Netzfehler gehören in Validate.

### H1 — Hoch: Der Secret-Scanner ist auf Standard-macOS fail-open und kann rohe Treffer speichern

**Behauptung:** `secret-sweep` kann wegen einer nicht deklarierten `timeout`-Abhängigkeit jeden Scan überspringen und trotzdem „ok“ ausgeben; bei echten Treffern schreibt es Felder mit Secret-/Match-Inhalt auf Disk.

**Evidenz:** Das Skript fordert nur `gitleaks` explizit ([automation/bin/secret-sweep, Z. 119–126](../../automation/bin/secret-sweep#L119-L126)), startet Scans aber über `timeout … || true` und wertet leere Ausgabe im `else` als „ok“ ([automation/bin/secret-sweep, Z. 149–188](../../automation/bin/secret-sweep#L149-L188)). Bei Treffern werden gerade die JSON-Felder `"Secret"` und `"Match"` in `local/secret-sweep.md` geschrieben ([automation/bin/secret-sweep, Z. 169–185](../../automation/bin/secret-sweep#L169-L185)). Auf der Zielmaschine war weder `timeout` noch `gtimeout` vorhanden; die Repository-Deklarationen installieren `coreutils` nicht.

**Interpretation:** Ein fehlendes Hilfsprogramm wird als sauberer Scan fehlklassifiziert. Im gegenteiligen Fall kann der Scanner die zu schützenden Werte selbst in einer unverschlüsselten Datei persistieren.

**Gegenprüfung:** `local/` ist gitignoriert, und ein direkter redaktierter Gitleaks-Lauf über dieses Repository war sauber. Das begrenzt die Veröffentlichung, nicht den lokalen Klartext- oder False-negative-Risk über andere Repositories.

**Begrenzte Maßnahme:** Einen vorhandenen portablen Timeout-Mechanismus erkennen oder als harte Abhängigkeit deklarieren; Scannerstart-/Timeout-/Parsefehler dürfen niemals „ok“ ergeben. Gitleaks mit `--redact` ausführen, keine Secret-/Match-Werte in Berichte übernehmen und Dateirechte restriktiv setzen. Ein Fixture mit absichtlichem Testsecret muss den Pfad rot machen.

### H2 — Hoch: Der akzeptierte `curl | bash`-Pfad hat zu schwache Repository- und Workflow-Kontrollen

**Behauptung:** Nicht `curl | bash` selbst, sondern die Kombination aus mutablem `main`, ungeschütztem Hauptbranch und nicht per Commit-SHA fixierten Drittanbieter-Actions macht die offen akzeptierte Vertrauensentscheidung unnötig breit.

**Evidenz:** Der primäre Quickstart lädt direkt von `main` und führt den Inhalt aus ([README.md, Z. 33–41](../../README.md#L33-L41)). Das Threat Model benennt Repo-/CDN-Kompromittierung ausdrücklich ([SECURITY.md, Z. 18–24](../../SECURITY.md#L18-L24)). CODEOWNERS weist selbst darauf hin, dass erst Branch Protection die Regel bindend macht ([.github/CODEOWNERS, Z. 1–10](../../.github/CODEOWNERS#L1-L10)). Read-only GitHub-Abfragen ergaben am Reviewtag für `main` weder Branch Protection noch Rulesets. Zugleich laufen schreibberechtigte Workflows mit beweglichen Action-Tags, darunter `peter-evans/create-pull-request@v6` ([.github/workflows/up2date.yml, Z. 39–42](../../.github/workflows/up2date.yml#L39-L42), [.github/workflows/up2date.yml, Z. 122–129](../../.github/workflows/up2date.yml#L122-L129)) und `actions/checkout@v4` im Release ([.github/workflows/release.yml, Z. 43–50](../../.github/workflows/release.yml#L43-L50)).

**Interpretation:** Jede Änderung auf `main` wird unmittelbar zu ausführbarem Installationscode. Ohne verpflichtende Reviews/Checks und immutable Action-Referenzen fehlt Defense in Depth für genau den höchsten öffentlichen Vertrauenspfad.

**Gegenprüfung:** HTTPS, öffentliche Nachprüfbarkeit und die Anleitung „clone and inspect“ sind vorhanden; GitHub Secret Scanning und Push Protection waren aktiviert. Das Repository beschreibt das Restrisiko ehrlich.

**Begrenzte Maßnahme:** `main` durch verpflichtenden Validate-Check, CODEOWNER-Review und eingeschränkte Pushes schützen; alle Actions auf vollständige Commit-SHAs pinnen. Als empfohlenen Installationspfad einen Release-Tag oder Commit plus Checksum/Signatur dokumentieren; den beweglichen `main`-Einzeiler klar als bewusstes Latest/Convenience-Verhalten kennzeichnen.

### H3 — Hoch: CHANGELOG-Inhalt wird in einem schreibberechtigten Release-Shellschritt interpoliert

**Behauptung:** Kontrollierbarer Markdown-Inhalt kann beim nächsten `v*`-Tag zu Shellsyntax im Release-Job werden.

**Evidenz:** Der Workflow liest bis zu 200 freie Zeilen aus dem Abschnitt `[Unreleased]` in einen Step-Output ([.github/workflows/release.yml, Z. 77–105](../../.github/workflows/release.yml#L77-L105)). Im nächsten `run:`-Block wird `${{ steps.notes.outputs.notes }}` direkt innerhalb eines doppelt gequoteten Shellarguments eingesetzt ([.github/workflows/release.yml, Z. 110–127](../../.github/workflows/release.yml#L110-L127)), während der Job `contents: write` besitzt ([.github/workflows/release.yml, Z. 18–24](../../.github/workflows/release.yml#L18-L24)). Ein Anführungszeichen oder eine Command-Substitution im Changelog wird vor Ausführung in das generierte Skript eingesetzt.

**Interpretation:** Nach Merge eines präparierten Changelog-Eintrags und anschließendem Tag kann der Release-Runner Befehle unter dem Repository-Token ausführen. Für eine öffentliche Contribution-Oberfläche ist direkte Expression-Interpolation in Shell ein bekannter Trust-Boundary-Fehler.

**Gegenprüfung:** Ein Pull Request allein startet diesen Workflow nicht; der Inhalt muss erst auf dem getaggten Stand landen, und Validate läuft davor. Validate prüft jedoch keine semantische Sicherheit dieses dynamischen Shelltexts, und `main` war ungeschützt.

**Begrenzte Maßnahme:** Release Notes in eine Datei schreiben und `gh release --notes-file` verwenden. Dynamische Werte ausschließlich über `env:` oder Dateien transportieren und einen Test mit Anführungszeichen, `$()` und dem GitHub-Output-Delimiter ergänzen.

### H4 — Hoch: Stufen und Lifecycle-Status steuern die tatsächliche Installation nicht zuverlässig

**Behauptung:** Niedrige Bootstrap-Stufen installieren Werkzeuge höherer Stufen; sogar als `candidate` markierte Pakete werden standardmäßig installiert. Damit ist die Registry nicht die behauptete Quelle der Installationsentscheidung.

**Evidenz:** Die öffentliche Tabelle verspricht Docker, Gemini und Ollama erst ab Level 2 ([README.md, Z. 43–48](../../README.md#L43-L48)). Bootstrap verwendet aber ab Level 1 den vollständigen `Brewfile` ([bootstrap.sh, Z. 285–290](../../bootstrap.sh#L285-L290)), der Ollama/Gemini und den Docker-Cask enthält ([Brewfile, Z. 61–65](../../Brewfile#L61-L65), [Brewfile, Z. 119–125](../../Brewfile#L119-L125)). Modul 04 installiert sieben hart codierte globale npm-Pakete auf jeder Stufe ([scripts/04-node.sh, Z. 138–167](../../scripts/04-node.sh#L138-L167)); mehrere davon sind in der Registry ausdrücklich Level-3-`candidate`, beispielsweise OmniRoute, mcporter, ruflo und uipro-cli ([manifests/tools.yaml, Z. 574–632](../../manifests/tools.yaml#L574-L632)).

**Interpretation:** Zeit-, Umfangs- und Vertrauensgrenzen der Stufen sind faktisch falsch. Besonders problematisch ist die automatische Installation von Kandidaten, obwohl INV-1 einen menschlichen Adoption-Schritt verlangt.

**Gegenprüfung:** Die Modulauswahl selbst ist nach Stufen gegliedert, Level 0 besitzt einen eigenen Brewfile, und das AI-Modul bricht bei Level 0/1 nach Claude ab. Die Umgehung entsteht in gemeinsam genutzten Paketlisten und Hardcodings.

**Begrenzte Maßnahme:** Installationspläne aus `status=active` und `level<=gewählt` generieren oder pro Stufe trennen; `candidate` grundsätzlich nie im Standard-Bootstrap installieren. CI muss für jede installierte Referenz Quelle, Status und Stufe gegen die Registry prüfen.

### H5 — Hoch: Bootstrap meldet Erfolg trotz Modul- oder Doctor-FAIL

**Behauptung:** Der Orchestrator kann fehlgeschlagene Module und Doctor-Fehler verschlucken, anschließend „Bootstrap complete“ ausgeben und Exit 0 liefern.

**Evidenz:** Ein Modulfehler wird nur als Warnung registriert und kann fortgesetzt werden ([bootstrap.sh, Z. 224–234](../../bootstrap.sh#L224-L234)). Noch vor Doctor wird bedingungslos „Bootstrap complete“ ausgegeben ([bootstrap.sh, Z. 394–402](../../bootstrap.sh#L394-L402)); Doctor läuft mit `--no-exit` plus `|| true` ([bootstrap.sh, Z. 437–447](../../bootstrap.sh#L437-L447)). Die README verspricht hingegen: „FAILs block the setup as complete“ ([README.md, Z. 100–106](../../README.md#L100-L106)). Der ausgeführte Level-0-Dry-run reproduzierte einen Doctor-FAIL bei Gesamt-Exit 0.

**Interpretation:** Automatisierung und Erstnutzer können einen unvollständigen Zustand als erfolgreich behandeln. Das beschädigt die Verlässlichkeit aller nachfolgenden Setup- und Migrationserwartungen.

**Gegenprüfung:** Die Zusammenfassung zeigt Warnungen, interaktive Nutzer können den Fortgang ablehnen, und der allein ausgeführte Doctor liefert bei FAIL korrekt Exit 1 ([doctor.sh, Z. 680–690](../../doctor.sh#L680-L690)). Der Fehler liegt in der Orchestrierung.

**Begrenzte Maßnahme:** Modul- und Doctor-Fehler aggregieren, „complete“ nur bei erfülltem Abschlusskriterium ausgeben und andernfalls ungleich 0 enden. Fortsetzung nach Fehlern als explizite Option (`--continue-on-error`) behandeln, nicht als Erfolgssemantik.

### H6 — Hoch: Das globale Dry-run-/Help-Versprechen ist nicht erfüllt

**Behauptung:** Mehrere zustandsändernde Kommandos ignorieren unbekannte Optionen, besitzen kein wirksames `--help` und verändern selbst im Dry-run das Dateisystem; damit ist der dokumentierte Audit-Pfad nicht rein read-only.

**Evidenz:** INV-5 fordert „`--help` and `--dry-run` on every command“ ([BIBLE.md, Z. 34–37](../../BIBLE.md#L34-L37)), und SECURITY verspricht, Dry-run führe nichts aus ([SECURITY.md, Z. 35–40](../../SECURITY.md#L35-L40)). Modul 04 akzeptiert still nur zwei bekannte Argumente und würde `--help` danach normal ausführen ([scripts/04-node.sh, Z. 15–22](../../scripts/04-node.sh#L15-L22)); sein `mkdir -p "$PNPM_HOME"` liegt außerhalb der Dry-run-Abstraktion ([scripts/04-node.sh, Z. 75–90](../../scripts/04-node.sh#L75-L90)). Vergleichbar erstellt Modul 07 das Claude-Verzeichnis direkt ([scripts/07-ai-stack.sh, Z. 61–74](../../scripts/07-ai-stack.sh#L61-L74)), und Modul 08 führt `chmod`/`mkdir` direkt aus ([scripts/08-git-ssh.sh, Z. 189–195](../../scripts/08-git-ssh.sh#L189-L195), [scripts/08-git-ssh.sh, Z. 233–244](../../scripts/08-git-ssh.sh#L233-L244)). Beim Testlauf erschien zudem eine Corepack-Download-Ankündigung.

**Interpretation:** Der empfohlene Sicherheitscheck kann lokale Verzeichnisse/Rechte ändern und abhängige Shims zu Netzwerkzugriff veranlassen. Unbekannte Flags als stilles „weiter“ erhöhen das Risiko von Tippfehlern bei öffentlich kopierten Befehlen.

**Gegenprüfung:** Viele eigentliche Mutationen laufen korrekt über `run`, `prepare.sh --check-only` bestand read-only, und destruktive Cleanup-Werkzeuge sind überwiegend opt-in. Der Befund ist daher behebbarer Contract-Drift, keine pauschale Behauptung, jeder Dry-run installiere Software.

**Begrenzte Maßnahme:** Einen gemeinsamen strikten Argumentparser verwenden; `--help` muss vor jeder Aktion enden und unbekannte Optionen müssen Exit 2 liefern. Alle direkten Writes in die Dry-run-Abstraktion ziehen und jedes Executable in CI unter temporärem HOME mit Vorher-/Nachher-Dateisystem- und Prozess/Netzwerk-Kontrolle testen.

### H7 — Hoch: Der vorgeschriebene lokale Gate bricht ohne Urteil ab und ist nicht CI-paritätisch

**Behauptung:** `scripts/gate.sh` ist auf der vorgesehenen Maschine nicht selbstgenügsam und beendet sich bei fehlendem PyYAML vor `GATE: FAIL`; lokal und CI prüfen unterschiedliche Implementierungen.

**Evidenz:** INV-6/7 fordert einen tatsächlich blockierenden Gate und dieselbe Oberfläche lokal wie in CI ([BIBLE.md, Z. 38–41](../../BIBLE.md#L38-L41)). Der Gate nutzt `eval` ([scripts/gate.sh, Z. 1–12](../../scripts/gate.sh#L1-L12)), warnt selbst vor einem bloßen `exit` in einem evaluierten Check ([scripts/gate.sh, Z. 83–87](../../scripts/gate.sh#L83-L87)), verwendet genau dieses Muster aber direkt danach mit `python3 -c "import yaml…" || exit 1` ([scripts/gate.sh, Z. 95–104](../../scripts/gate.sh#L95-L104)). Der aktuelle Lauf endete nach `ModuleNotFoundError: No module named 'yaml'`, Exit 1, ohne `GATE: FAIL`. CI installiert `yq`, `jq`, `shellcheck` und parst YAML mit `yq` ([.github/workflows/validate.yml, Z. 43–47](../../.github/workflows/validate.yml#L43-L47), [.github/workflows/validate.yml, Z. 209–224](../../.github/workflows/validate.yml#L209-L224)), nicht mit dem undeclared PyYAML-Pfad.

**Interpretation:** Der in Handoff und Contributor-Dokumentation verlangte lokale Abschlussnachweis ist nicht reproduzierbar; ein früher Abbruch überspringt nachfolgende Security-Checks. Die behauptete CI-Parität existiert als duplizierter Code, nicht als gemeinsame ausführbare Quelle.

**Gegenprüfung:** CI war für den geprüften Commit grün; separat ausgeführte ShellCheck-, Syntax-, Plist-, YAML-, Sanitization- und Konsistenzchecks bestanden. Das bestätigt den Codezustand, nicht die Funktionsfähigkeit des lokalen Gates.

**Begrenzte Maßnahme:** Jede Prüfung in ein versioniertes Skript extrahieren, das Gate und Workflow identisch aufrufen; nur deklarierte Werkzeuge nutzen und kein `eval`/bloßes `exit` in Checkstrings. Einen Selbsttest hinzufügen, der sowohl PASS als auch absichtlichen FAIL inklusive genau eines Abschlussurteils prüft. Die nicht vorhandene Beispielreferenz `.github/sanitize-check.sh` in CONTRIBUTING ersetzen ([CONTRIBUTING.md, Z. 36–52](../../CONTRIBUTING.md#L36-L52)).

### H8 — Hoch: Die Publication-Kontrolle erfasst nicht „alle Textdateien“ und CI führt Gitleaks nicht aus

**Behauptung:** Die dokumentierte Sanitization-Abdeckung ist wesentlich enger als behauptet und lässt gerade ausführbare extensionlose Dateien, Git-Konfiguration und `.env.example` außerhalb der Prüfung; die Gitleaks-Konfiguration behauptet zudem eine CI-Nutzung, die nicht existiert.

**Evidenz:** Die Dokumentation sagt, Validate prüfe „all text files“ ([docs/05-SANITIZATION.md, Z. 59–70](../05-SANITIZATION.md#L59-L70)). Tatsächlich wählt der Workflow nur eine Erweiterungs-Allowlist aus ([.github/workflows/validate.yml, Z. 128–140](../../.github/workflows/validate.yml#L128-L140)). Eine Reproduktion der Auswahl ließ unter anderem `config/gitconfig`, `automation/bin/env-run` und `templates/vaultwarden/.env.example` aus. `.gitleaks.toml` behauptet Nutzung durch CI und nimmt alle `.env.example`-Pfade vollständig aus ([.gitleaks.toml, Z. 1–15](../../.gitleaks.toml#L1-L15)); `validate.yml` besitzt jedoch keinen Gitleaks-Schritt. SECURITY verspricht, Sanitization blockiere versehentlich eingecheckte Secrets ([SECURITY.md, Z. 42–47](../../SECURITY.md#L42-L47)).

**Interpretation:** Die grüne CI vermittelt für einen öffentlichen Release einen zu starken Publication-Nachweis. Erweiterungslose CLIs und Beispiel-Env-Dateien sind gerade typische Träger von Tokens, URLs oder privaten Pfaden.

**Gegenprüfung:** Die tatsächlich ausgewählten Dateien bestanden den Denylist-Scan; ein separater Gitleaks-History-Scan war sauber, und GitHub Secret Scanning/Push Protection waren aktiviert. Das reduziert den aktuellen Befund, repariert aber nicht die zukünftige CI-Abdeckung.

**Begrenzte Maßnahme:** Von `git ls-files -z` ausgehen, Binärdateien sicher erkennen und alle übrigen verfolgten Inhalte prüfen. Gitleaks mit Default-Regeln und `--redact` in CI ausführen; Pfad-Allowlisting von `.env.example` durch eng begrenzte Testfingerprints ersetzen. Der lokale private Denylist ist zusätzliche Entwicklerkontrolle, darf aber nicht als in GitHub verfügbare CI-Kontrolle dargestellt werden.

### H9 — Hoch: Der Vault-Session-Token ist entgegen der Sicherheitsdarstellung in Prozessargumenten sichtbar

**Behauptung:** `env-run` schützt zwar die aufgelösten Zielwerte, übergibt aber den als „vault key“ klassifizierten `BW_SESSION`-Token als Kommandozeilenargument, beim optionalen Server sogar an einen länger laufenden Prozess.

**Evidenz:** Die Secrets-Dokumentation nennt `BW_SESSION` „equivalent to a vault key“ ([docs/08-SECRETS.md, Z. 215–229](../08-SECRETS.md#L215-L229)) und behauptet, Secrets erschienen nicht in `ps` ([docs/08-SECRETS.md, Z. 286–299](../08-SECRETS.md#L286-L299)). `env-run` ruft dagegen `bw status/get … --session "$BW_SESSION"` auf ([automation/bin/env-run, Z. 50–64](../../automation/bin/env-run#L50-L64), [automation/bin/env-run, Z. 87–104](../../automation/bin/env-run#L87-L104)) und startet `bw serve` ebenso ([automation/bin/env-run, Z. 120–139](../../automation/bin/env-run#L120-L139)). Kommandozeilenargumente sind über Prozesslisten sichtbar.

**Interpretation:** Die wertvollste Fähigkeit im Ablauf — der entschlüsselte Session-Schlüssel — überschreitet die dokumentierte `ps`-Grenze. Beim Servermodus vergrößert die Laufzeit das Beobachtungsfenster.

**Gegenprüfung:** Die eigentlichen Zielvariablen werden anschließend in einer Subshell exportiert und via `exec` vererbt, nicht als `env KEY=value` in argv ([automation/bin/env-run, Z. 616–633](../../automation/bin/env-run#L616-L633)). Dieser Teil der Implementierung entspricht dem Entwurf; betroffen ist der vorgelagerte Session-Transport.

**Begrenzte Maßnahme:** Die bereits geerbte Umgebungsvariable `BW_SESSION` vom Bitwarden-CLI verwenden und `--session` aus Argumentlisten entfernen; den Servermodus separat prüfen oder vermeiden. Ein Prozesslisten-Test darf weder Session noch aufgelöste Werte finden.

### H10 — Hoch: Der dokumentierte private Meldekanal ist deaktiviert

**Behauptung:** SECURITY verweist ausschließlich auf GitHub Private Vulnerability Reporting, obwohl die Funktion für das öffentliche Repository nicht aktiviert ist.

**Evidenz:** `SECURITY.md` verbietet öffentliche Issues und fordert den Button „Report a vulnerability“ mit Sieben-Tage-Antwort ([SECURITY.md, Z. 3–12](../../SECURITY.md#L3-L12)). Die read-only GitHub-Abfrage `private-vulnerability-reporting` ergab am Reviewtag `enabled: false`; damit steht der beschriebene Button externen Meldenden nicht zur Verfügung. Ein alternativer privater Kontakt ist in der Datei nicht angegeben.

**Interpretation:** Sicherheitsforscher haben keinen regelkonformen Kanal. Für eine öffentliche Repo, die lokale Entwicklercredentials und Installationspfade berührt, ist das ein konkreter Disclosure- und Contributor-UX-Defekt.

**Gegenprüfung:** Issues und Community-Dateien sind vorhanden, aber SECURITY untersagt zu Recht die öffentliche Offenlegung; sie sind deshalb kein Ersatzkanal.

**Begrenzte Maßnahme:** Private Vulnerability Reporting aktivieren und als ausgeloggter Besucher verifizieren oder eine funktionierende private Sicherheitsadresse ergänzen. Die Antwortfrist nur beibehalten, wenn sie operativ getragen werden kann.

### M1 — Mittel: Level 1 deaktiviert ohne gesonderte Zustimmung Download-Quarantäne

**Behauptung:** Ein als allgemeine Entwicklerpräferenz eingeordnetes Standardmodul setzt `LSQuarantine=false`, obwohl dies eine Sicherheitskontrolle und keine bloße UI-Präferenz ist.

**Evidenz:** Modul 09 wird ab Level 1 automatisch ausgeführt ([bootstrap.sh, Z. 337–342](../../bootstrap.sh#L337-L342)). Unter „Security settings“ schreibt es `com.apple.LaunchServices LSQuarantine -bool false` und meldet „Quarantine dialog for downloads disabled“ ([scripts/09-macos-defaults.sh, Z. 155–162](../../scripts/09-macos-defaults.sh#L155-L162)). Header und Usage nennen nur allgemeine macOS-Defaults, Dry-run und Yes-Modus ([scripts/09-macos-defaults.sh, Z. 1–24](../../scripts/09-macos-defaults.sh#L1-L24)).

**Interpretation:** Erstnutzer können diese sicherheitsrelevante Systemänderung aus dem Stufenversprechen nicht erwarten. Der Kommentar „Safe Mode remains active“ erklärt die verbleibenden macOS-Schutzschichten nicht und ist kein Opt-in.

**Gegenprüfung:** Diese Einstellung allein deaktiviert nicht automatisch alle Gatekeeper-/XProtect-Funktionen; der Befund behauptet nur die gezielte Abschaltung der Download-Quarantäne. `df_write` respektiert Dry-run.

**Begrenzte Maßnahme:** Aus dem Standard entfernen oder hinter einen benannten Security-Relaxation-Flag mit Erklärung, Bestätigung und Rücksetzkommando legen; Doctor sollte die Abweichung sichtbar machen.

### M2 — Mittel: `db-backup` löscht bei jedem normalen Lauf ohne expliziten Prune-Opt-in

**Behauptung:** Automatische Rotation verletzt die repo-eigene Regel, nach der jeder löschende Befehl einen expliziten Opt-in benötigt.

**Evidenz:** INV-2 sagt: „Every command that can delete requires an explicit opt-in“ ([BIBLE.md, Z. 26–29](../../BIBLE.md#L26-L29)). `db-backup` dokumentiert Löschung als normalen Bestandteil ([automation/bin/db-backup, Z. 3–18](../../automation/bin/db-backup#L3-L18)) und entfernt nach einem regulären Lauf alle passenden Dumps älter als `KEEP_DAYS` mit `find … -delete` ([automation/bin/db-backup, Z. 282–294](../../automation/bin/db-backup#L282-L294)).

**Interpretation:** Retention ist sinnvoll, aber nach dem verbindlichen Sicherheitsmodell eine destruktive Aktion. Gerade Backup-Dateien haben keine automatische Sicherung vor dieser Löschung.

**Gegenprüfung:** Die Suche ist auf `BACKUP_BASE`, `*.sql.gz` und Alter begrenzt; Dry-run löscht nicht, und die Rotation ist im Header transparent. Das macht sie kontrolliert, aber nicht explizit opt-in.

**Begrenzte Maßnahme:** Rotation standardmäßig nur berichten und über `--prune`/`--apply-rotation` aktivieren; Zielpfad und Kandidatenliste vor Löschung validieren und ausgeben.

### M3 — Mittel: Das dokumentierte Registry-Schema wird nur teilweise validiert

**Behauptung:** Validate behauptet zwölf Schema-Regeln, prüft aber mehrere davon nicht, darunter `reviewed`, Datumsformat von `sunset`, `replaced_by`-Referenzen und die Vollständigkeit aller Pflichtfelder.

**Evidenz:** Das Schema bezeichnet alle Felder als erforderlich und definiert Typen ([manifests/schema.md, Z. 5–27](../../manifests/schema.md#L5-L27)); die expliziten CI-Regeln verlangen gültige `reviewed`-/`sunset`-Daten und eine existierende `replaced_by`-ID ([manifests/schema.md, Z. 107–120](../../manifests/schema.md#L107-L120)). Der Workflow liest nur einen Teil der Felder und validiert als Datum ausschließlich `added` ([.github/workflows/validate.yml, Z. 240–313](../../.github/workflows/validate.yml#L240-L313)).

**Interpretation:** Formal ungültige Registry-Einträge können grün mergen und danach Currency/Sunset-Logik verfälschen. Bei der Registry als Single Source of Truth ist das mehr als Dokumentationskosmetik.

**Gegenprüfung:** Das aktuelle YAML ist syntaktisch gültig, IDs sind eindeutig, und die implementierten Wertemengen-/Statusregeln bestanden. Nicht nachgewiesen ist ein aktueller invalider Eintrag, sondern eine verifizierte Lücke im zugesagten Validator.

**Begrenzte Maßnahme:** Ein maschinenlesbares Schema oder einen einzigen vollständigen Validator bereitstellen und sowohl lokal als auch in CI aufrufen; negative Fixtures für jedes Pflichtfeld, ungültige Daten und fehlende `replaced_by`-Ziele ergänzen.

### M4 — Mittel: Die Migration verliert npm-Scopes

**Behauptung:** Die Bestandsaufnahme und der Soll/Ist-Vergleich reduzieren scoped Pakete wie `@scope/pkg` auf `pkg`; das Migrationsprofil kann deshalb falsche Installationsbefehle erzeugen.

**Evidenz:** `status-quo.sh` nimmt aus dem parseable npm-Pfad nur das letzte `/`-Segment ([status-quo.sh, Z. 151–168](../../status-quo.sh#L151-L168)). Dasselbe Muster steht in `migration-diff` ([automation/bin/migration-diff, Z. 335–348](../../automation/bin/migration-diff#L335-L348)) und `mac-snapshot` ([automation/bin/mac-snapshot, Z. 151–166](../../automation/bin/mac-snapshot#L151-L166)). Der Report erzeugt daraus direkt `npm install -g ${item}` ([automation/bin/migration-diff, Z. 354–365](../../automation/bin/migration-diff#L354-L365)). Eine isolierte Pfadprobe bestätigte den Verlust des Scope-Segments.

**Interpretation:** Gerade mehrere im Repository verwendete AI-CLIs sind scoped; damit ist ein Kernfall der beworbenen Maschinenmigration falsch abgebildet.

**Gegenprüfung:** Unscoped Pakete werden korrekt erfasst, und eine spätere Funktion kann Versionssuffixe von bereits vollständigen scoped Namen entfernen. Der Scope ist zu diesem Zeitpunkt jedoch bereits verloren.

**Begrenzte Maßnahme:** Paketnamen aus `npm ls -g --json --depth=0` über die Dependency-Keys lesen oder bei parseable Pfaden die letzten zwei Segmente für `@scope` bewahren; identische Fixtures in allen drei Werkzeugen verwenden.

### M5 — Mittel: Öffentliche Reproduzierbarkeits- und Supportaussagen widersprechen sich

**Behauptung:** Die README verwendet stärkere Begriffe als die Implementierung und die eigenen Nicht-Ziele tragen.

**Evidenz:** Sie nennt `Brewfile` „Pinned core packages“ ([README.md, Z. 145–157](../../README.md#L145-L157)), obwohl Einträge wie `brew "git"`, `brew "jq"` und `brew "shellcheck"` keine Version pinnen ([Brewfile, Z. 17–33](../../Brewfile#L17-L33)). Sie verspricht eine Umgebung, die „exactly one year from now“ reproduziert werden könne ([README.md, Z. 206–212](../../README.md#L206-L212)), erklärt aber korrekt, dass zeitversetzte Läufe wegen Homebrew- und OS-Drift verschieden sein werden ([README.md, Z. 196–202](../../README.md#L196-L202)). Der Badge nennt macOS 26+, während `prepare.sh` macOS 15+ fordert ([README.md, Z. 5–8](../../README.md#L5-L8), [prepare.sh, Z. 1–15](../../prepare.sh#L1-L15)).

**Interpretation:** Ein öffentlicher Erstnutzer kann Versionsfixierung und einen anderen Supportumfang erwarten, als der Code anbietet. Das schwächt eine ansonsten erfreulich ehrliche Positionierung.

**Gegenprüfung:** Die Nicht-Ziel-Sektion beschreibt die fehlende Byte-Reproduzierbarkeit ausdrücklich und korrekt. Das Design kann strukturelle Reproduzierbarkeit plus sichtbare Drift leisten; nur „pinned“ und „exactly“ überschreiten diesen belegten Anspruch.

**Begrenzte Maßnahme:** „Pinned/exactly“ durch „declared“, „structurally reproducible“ beziehungsweise „drift-visible“ ersetzen und einen einzigen getesteten macOS-Mindeststand nennen. Falls echte Pins gewollt sind, müssen Lock-/Checksum-Mechanismen implementiert und regelmäßig getestet werden.

## 4. Offene Entscheidungen — keine verifizierten Defekte

Diese Punkte benötigen eine bewusste Maintainer-Entscheidung; die Review improvisiert keine Vorgabe:

1. Soll der bequeme `main`-Einzeiler trotz akzeptiertem Risiko primär bleiben, oder soll ein Release-/Commit-pinnter Pfad die öffentliche Empfehlung werden?
2. Gilt die Lifecycle-Regel strikt so, dass `candidate` niemals automatisch installiert wird? Dokumentation und BIBLE sprechen dafür; die endgültige Produktentscheidung sollte explizit registriert werden.
3. Gehört `LSQuarantine=false` überhaupt zum öffentlichen Basisset, oder nur zu einem bewusst riskanten persönlichen Profil?
4. Welcher macOS-Stand ist wirklich unterstützt: 15+, 26+ oder nur der konkret inventarisierte Stand? Dafür fehlt noch eine Clean-Machine-Matrix.
5. Soll die lokale Vaultwarden-Vorlage bewusst `vaultwarden/server:latest` und initial offene Registrierung verwenden ([templates/vaultwarden/docker-compose.yml, Z. 1–18](../../templates/vaultwarden/docker-compose.yml#L1-L18)), oder soll auch dieser sensible Supply-Chain-Pfad gepinnt und als einmaliger Initialisierungsschritt gestaltet werden?
6. Welches Governance-Niveau ist für ein Single-Maintainer-Repository praktikabel: verpflichtender Review durch eine zweite Person, signierte/limitierte Pushes oder zumindest Rulesets mit Required Status Checks?

## 5. Stärken und bestätigte Annahmen

- **Ungewöhnlich ehrliche Scope-Kommunikation:** Nicht-Ziele und Threat Model benennen Single-Machine-, Supply-Chain- und Reproduzierbarkeitsgrenzen offen ([README.md, Z. 196–202](../../README.md#L196-L202), [SECURITY.md, Z. 14–24](../../SECURITY.md#L14-L24)). Diese Trade-offs wurden in den Befunden nicht als Defekte umetikettiert.
- **Guter minimaler Einstieg:** `prepare.sh` ist standalone, besitzt einen strikten Parser und kennzeichnet `--check-only` als garantiert unverändernd ([prepare.sh, Z. 1–24](../../prepare.sh#L1-L24), [prepare.sh, Z. 324–343](../../prepare.sh#L324-L343)). Der ausgeführte Check bestätigte dieses Verhalten; die Apple-ID-Prüfung zeigt nur Status, nie die Adresse ([prepare.sh, Z. 310–321](../../prepare.sh#L310-L321)).
- **Solide statische Baseline:** Alle Shell-Dateien bestanden Syntax und ShellCheck auf Warning-Level, alle sechs Plists bestanden `plutil`, Workflow/Registry-YAML ließ sich parsen, und Registry-Konsistenz bestand offline. Der separate redaktierte Gitleaks-History-Scan war sauber.
- **Sicherheitsmuster sind an mehreren Stellen gut umgesetzt:** `mac-clean` ist standardmäßig report-only und verlangt `--apply` ([automation/bin/mac-clean, Z. 13–16](../../automation/bin/mac-clean#L13-L16), [automation/bin/mac-clean, Z. 24–47](../../automation/bin/mac-clean#L24-L47)); Legacy-Cleanup ist ausdrücklich opt-in und sichert vor dem Entfernen ([scripts/90-cleanup-legacy.sh, Z. 3–20](../../scripts/90-cleanup-legacy.sh#L3-L20), [scripts/90-cleanup-legacy.sh, Z. 143–165](../../scripts/90-cleanup-legacy.sh#L143-L165)). Alle sechs LaunchAgent-Vorlagen setzen `RunAtLoad=false`, wie beispielhaft der Update-Job zeigt ([automation/launchd/dev.kickoff.mac-update.plist, Z. 30–38](../../automation/launchd/dev.kickoff.mac-update.plist#L30-L38)).
- **Gute öffentliche Projektoberfläche:** Lizenz, Contribution Guide, Code of Conduct, Issue-/PR-Templates, CODEOWNERS, Dependabot und Security Policy sind vorhanden. Der GitHub-Community-Health-Check war vollständig, der letzte Validate-Lauf grün, und Secret Scanning plus Push Protection waren aktiviert.
- **Richtige menschliche Kontrollidee:** Statusänderungen sollen ausdrücklich nicht automatisch erfolgen ([BIBLE.md, Z. 23–25](../../BIBLE.md#L23-L25)). Diese Architektur ist für einen nachvollziehbaren Setup-Lifecycle sinnvoll; Befund H4 betrifft ihre Durchsetzung, nicht die Entscheidung selbst.

## 6. Priorisierte Roadmap

### Sofort — vor einer uneingeschränkten öffentlichen Ausführungsempfehlung

1. **K1 schließen:** Git-Identität ausschließlich in `~/.gitconfig.local`; unveränderten Worktree nach Setup testen; Sanitization auf alle verfolgten Texte erweitern.
2. **H2/H3 absichern:** `main` schützen, Drittanbieter-Actions per SHA pinnen, Release-Notes über Datei statt Shellinterpolation transportieren; privaten Vulnerability-Kanal aktivieren.
3. **K2 fail-closed machen:** Nullfund/Cask/Fehlerpfade reparieren, gültiges JSON und Exitcodes erzwingen, Wochenworkflow ohne pauschales `|| true` testen.
4. **H1/H9 schließen:** Secret-Scanner portabel und redaktiert ausführen; Vault-Session aus argv entfernen.

**Abnahmekriterium:** Ein temporärer HOME-/Fixture-Test zeigt keine Repo- oder Secret-Artefakte; absichtliche Scanner-/Netz-/JSON-Fehler machen CI rot; ein adversariales Changelog kann keine Shellsyntax ausführen; Required Checks verhindern direkten unsicheren Merge nach `main`.

### Danach — öffentliche Verträge wieder wahr machen

5. **H4/H5/H6:** Installationsplan aus Registry-Status und Level ableiten, Bootstrap-Fehler aggregieren, Help/Dry-run für jedes Executable vertraglich testen.
6. **H7/H8/M3:** lokale und CI-Prüfungen in gemeinsame Skripte ziehen, Gitleaks in Validate ausführen und das vollständige Registry-Schema mit negativen Fixtures prüfen.
7. **M1/M2:** Quarantäne-Abschaltung bewusst entscheiden; Backup-Rotation explizit opt-in machen.

**Abnahmekriterium:** Für Level 0–3 existieren maschinenprüfbare Installationspläne ohne Kandidaten oder höhere Stufen; jeder Doctor-/Modulfehler erzeugt Exit ungleich 0; Gate und CI rufen dieselben Checks auf und liefern immer ein eindeutiges Urteil.

### Anschließend — Migration und öffentliche Erwartung schärfen

8. **M4:** scoped npm-Pakete in Snapshot, Profil und Diff end-to-end testen.
9. **M5:** Reproduzierbarkeits-, Pinning- und macOS-Supportsprache vereinheitlichen; mindestens einen frischen Ziel-Mac oder eine passende CI-Teststrategie dokumentieren.
10. Bewusste Entscheidungen aus Abschnitt 4 im Decision Register festhalten und nur die tatsächlich garantierten Eigenschaften als Badges/Quickstart-Versprechen führen.

## 7. Gesamturteil

Das Repository hat ein verständliches, öffentlich nützliches Vorhaben und eine bessere Selbstbeschreibung als viele Setup-Repositories. Seine größte Schwäche ist nicht die bewusst begrenzte Reproduzierbarkeit, sondern die Lücke zwischen starken Sicherheits-/Verifikationsversprechen und den tatsächlich ausführbaren Pfaden. K1 und K2 sind Release-Blocker für eine uneingeschränkte Empfehlung; H1 bis H10 sind überwiegend klar begrenzbare Engineering-Aufgaben. Nach Schließung dieser Trust-Boundary- und Fail-closed-Lücken wäre die vorhandene Architektur — gestufter Bootstrap, menschlich gesteuerter Lifecycle, Doctor, Migration und transparente Nicht-Ziele — eine belastbare Basis für ein öffentliches Projekt.
