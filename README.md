# bash-explain

Automatische Fehler-Erklärung für Bash-Befehle: Schlägt ein Kommando fehl, wird die Fehlerausgabe automatisch auf Deutsch erklärt — was passiert ist und wie man es behebt. Die Erklärung erzeugt ein lokales [Ollama](https://ollama.com)-Modell, ohne Cloud.

Ein-Datei-Projekt: `bash-explain.sh` wird in `~/.bashrc` gesourct und hängt sich danach in jede interaktive Shell ein.

## So funktioniert es

1. stderr der Shell bleibt sichtbar und wird zusätzlich in eine temporäre Datei geschrieben (`tee` über Prozesssubstitution).
2. Ein `DEBUG`-Trap merkt sich den zuletzt ausgeführten Befehl (`$BASH_COMMAND`).
3. `PROMPT_COMMAND` prüft nach jedem Prompt: Exit-Code ≠ 0 und stderr nicht leer → Befehl und Fehlerausgabe gehen an `ollama run codellama`, das als „geduldiger Linux-Lehrer für Anfänger“ in 2–3 deutschen Sätzen antwortet.

## Voraussetzungen

- Bash (interaktive Shell)
- [Ollama](https://ollama.com) läuft lokal, Modell `codellama` (`ollama pull codellama`)

## Nutzung

```bash
git clone https://github.com/smlfg/bash-explain.git
```

Danach in `~/.bashrc` einhängen (Pfad an die eigene Ablage anpassen) und eine neue Shell öffnen:

```bash
source ~/bash-explain/bash-explain.sh
```

Die Meldung „🎓 Bash-Erklärer aktiv.“ beim Shellstart bestätigt die Aktivierung.

## Repo-Inhalt

| Pfad | Rolle |
|---|---|
| `bash-explain.sh` | Das gesamte Projekt: Hook in die interaktive Shell plus Aufruf des lokalen Erklär-Modells |

## Grenzen

- Nur für interaktive Shells gedacht; in Skripten nicht sourcen (`PROMPT_COMMAND`/Trap-Verhalten).
- Erklärt nur Fehler mit stderr-Ausgabe; stille Fehler (nur Exit-Code) bleiben unkommentiert.
- Jeder fehlgeschlagene Befehl stößt einen LLM-Lauf an — die Antwortzeit hängt von Rechner und Modell ab.
- Die Shell bekommt eine eigene stderr-Weiterleitung (`exec 2> >(tee …)`); Werkzeuge, die stderr-Verhalten exakt auswerten, können davon betroffen sein.
- Die Temporärdatei liegt in `/tmp` und wird beim Shell-Exit entfernt (`trap … EXIT`).

## Lizenz

Keine Lizenzangabe in diesem Repository.
