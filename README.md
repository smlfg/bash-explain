# bash-explain

[![Status](https://img.shields.io/badge/status-active-success.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-%3E=4.0-green.svg)]()
[![Ollama](https://img.shields.io/badge/ollama-local-black.svg)](https://ollama.com)
[![Model](https://img.shields.io/badge/model-codellama-orange.svg)]()
[![Maintained by](https://img.shields.io/badge/maintained%20by-Samuel%20Fleig-blueviolet.svg)]()

> Automatische Fehler-Erklärung für Bash — schlägt ein Kommando fehl, antwortet ein lokales Ollama-Modell auf Deutsch: „Was ist passiert? Wie behebe ich es?" Cloud-frei, offline-fähig, eine einzige Datei.

---

## Inhaltsverzeichnis

- [Was macht es?](#was-macht-es)
- [Wie funktioniert es?](#wie-funktioniert-es)
- [Installation](#installation)
- [Beispiel-Session](#beispiel-session)
- [Konfiguration & Tuning](#konfiguration--tuning)
- [Grenzen](#grenzen)
- [Sicherheit & Datenschutz](#sicherheit--datenschutz)
- [Mitmachen](#mitmachen)
- [Lizenz](#lizenz)
- [Autor](#autor)

---

## Was macht es?

`bash-explain.sh` hängt sich als Source-Snippet in deine interaktive Bash-Shell. Ab dem Moment, wo du es in `~/.bashrc` eingehängt hast, passiert Folgendes bei **jedem** Kommando:

1. Der Befehl läuft wie gewohnt.
2. Wenn er mit Exit-Code `≠ 0` endet **und** etwas auf `stderr` gelandet ist, geht eine Anfrage an ein lokales Ollama-Modell (Default: `codellama`).
3. Das Modell bekommt den Prompt: „Du bist ein geduldiger Linux-Lehrer für Anfänger. Befehl: … Fehler: … Erkläre in 2–3 kurzen Sätzen auf Deutsch: 1) Was ist passiert? 2) Wie behebe ich es?"
4. Die Antwort erscheint unter `💡 Erklärung:` direkt unter dem fehlgeschlagenen Befehl — kein Popup, keine Verzögerung im Vordergrund, das Prompt kehrt sofort zurück, sobald das Modell fertig ist.

**Zielgruppe:** Lernende Shell-Nutzer, die Fehlermeldungen lesen lernen wollen, ohne jede in eine Suchmaschine zu kopieren. **Kein Ziel:** Produktiv-Code-Refactoring oder CI-Logging — dafür ist das Tool nicht gedacht.

---

## Wie funktioniert es?

Die Magie steckt in vier Bash-Mechanismen, alle in ~50 Zeilen untergebracht:

| Mechanismus | Was es tut |
|---|---|
| `exec 2> >(tee "$BASH_ERROR_FILE" >&2)` | Schiebt `stderr` durch `tee` in eine temporäre Datei **und** behält die sichtbare Ausgabe im Terminal. So sieht der Nutzer weiterhin, was schiefläuft, und das Skript hat den Text trotzdem zur Hand. |
| `trap 'LAST_BASH_CMD=$BASH_COMMAND' DEBUG` | Merkt sich bei jedem ausgeführten Befehl den letzten `$BASH_COMMAND` in einer Shell-Variable. |
| `PROMPT_COMMAND="_explain_error; …"` | Vor jedem neuen Prompt wird `_explain_error` aufgerufen — der Reihe nach, als Erstes (bestehende `PROMPT_COMMAND`-Hooks werden erhalten). |
| `_explain_error` | Prüft `$?` (Exit-Code des letzten Vordergrundbefehls) **und** ob `$BASH_ERROR_FILE` Inhalt hat. Wenn ja: Datei leeren, Schlaf `0.1s` (race-frei zu asynchronem `tee`), Prompt nachbauen, an `ollama run codellama --nowordwrap` pipen. |
| `trap 'rm -f "$BASH_ERROR_FILE"' EXIT` | Cleanup beim Shell-Exit. |

**Flussdiagramm:**

```
Kommando läuft → Exit-Code ≠ 0? ─── nein ─→ Prompt zurück
                       │
                       ja, stderr leer? ─── ja ──→ Prompt zurück (silent failure)
                       │
                       ja
                       ↓
              Prompt an Ollama (local, kein Netz)
                       ↓
              „💡 Erklärung: …" landet unter dem Befehl
                       ↓
                  Prompt zurück
```

**Wichtig:** Die stderr-Umleitung wird **einmal pro Shell** via `exec 2> …` gesetzt. Werkzeuge, die `stderr` exakt auswerten (z. B. manche Build-Tools mit Stream-Trennung), sehen ab dann stattdessen die `tee`-Pipe — siehe [Grenzen](#grenzen).

---

## Installation

### 1. Repository klonen

```bash
git clone https://github.com/smlfg/bash-explain.git ~/bash-explain
```

### 2. Ollama installieren & Modell ziehen

```bash
# Ollama installieren (Linux/macOS — siehe https://ollama.com)
curl -fsSL https://ollama.com/install.sh | sh

# Codellama-Modell lokal ablegen (~3.8 GB)
ollama pull codellama

# Service-Hintergrund starten (einmalig pro Login)
ollama serve &
```

### 3. In `~/.bashrc` einhängen

```bash
echo 'source ~/bash-explain/bash-explain.sh' >> ~/.bashrc
```

### 4. Neue Shell öffnen & testen

```bash
exec bash
$ ls /does-not-exist
ls: cannot access '/does-not-exist': No such file or directory
💡 Erklärung:
…
🎓 Bash-Erklärer aktiv. Fehler werden automatisch erklärt.
```

Die Startmeldung bestätigt, dass der Hook sitzt.

---

## Beispiel-Session

```bash
$ apt install nginx
E: Could not open lock file /var/lib/dpkg/lock-frontend - open (13: Permission denied)
💡 Erklärung:
Du hast versucht, apt ohne Root-Rechte auszuführen. Pakete darf nur der Benutzer root (oder via sudo) installieren. Wiederhole den Befehl mit vorangestelltem `sudo`, dann wird die Sperrdatei beschreibbar.
```

```bash
$ python3 -m http.server
Traceback (most recent call or call last):
  File "/usr/lib/python3.11/http/server.py", line 1293, in <module>
    test(_BaseHTTPRequestHandler,
ImportError: cannot import name '_BaseHTTPRequestHandler' from 'http.server'
💡 Erklärung:
Das Modul http.server hat in Python 3.11 ein internes Symbol umbenannt. Du nutzt vermutlich ein Skript für eine ältere Python-Version. Probiere Python 3.10 oder passe den Import im aufgerufenen Skript auf den korrekten Namen an.
```

```bash
$ git push origin main
fatal: No configured push destination
💡 Erklärung:
Git weiß nicht, wohin es pushen soll — entweder fehlt das Remote oder die Branch ist nirgends als upstream gesetzt. Lege mit `git remote add origin <url>` ein Remote an und pushe erneut mit `git push -u origin main`.
```

Antwortzeit ist erwartungsgemäß 1–4 Sekunden auf einer durchschnittlichen CPU. Erstes Auftauchen des Modells im RAM ist deutlich langsamer (Modell wird kalt geladen).

---

## Konfiguration & Tuning

| Variable | Default | Zweck |
|---|---|---|
| `BASH_ERROR_FILE` | `/tmp/bash_stderr_$$` | Speicherort der Stderr-Sammeldatei |
| Ollama-Modell | `codellama` | Andere Modelle funktionieren auch (`llama3`, `mistral`, `qwen2.5-coder`), einfach das Script editieren und Modellname ersetzen. |
| `sleep 0.1` in `_explain_error` | — | Pufferzeit, damit `tee` den Stderr-Inhalt fertig geschrieben hat, bevor die Datei gelesen wird. Auf langsamen Systemen ggf. erhöhen. |

**Modell wechseln:** Zeile 44 in `bash-explain.sh`:

```bash
… | ollama run llama3 --nowordwrap
```

**Stille Fehler (nur Exit-Code, kein stderr):** aktuell unerkannt. Wer das beheben will: `_explain_error` so erweitern, dass auch `$exit_code > 0 && ! -s "$BASH_ERROR_FILE"` getriggert wird (z. B. mit Default-Fehlermeldung „Exit-Code N, aber keine stderr-Zeile").

---

## Grenzen

- **Modelllatenz.** Ollama-Calls sind nicht gratis: 1–4 s pro Fehler auf CPU, bei großen Modellen oder leerem Modell-Cache auch deutlich mehr. Bei „Hammer auf Enter, hammer auf Enter" kann die Erklärung nachhängen.
- **Keine GPU-Beschleunigung out-of-the-box.** Wer CUDA-fähige Hardware hat, kann Ollama mit nativer GPU-Bindung betreiben — das ist hier nicht eingerichtet. Per Default läuft alles auf CPU.
- **Nur interaktive Shells.** In Skripten NICHT sourcen — `PROMPT_COMMAND` und die Traps würden das gesamte Skriptverhalten ändern.
- **Stderr-Umleitung bleibt aktiv.** `exec 2> >(tee …)` ist eine einmalige, dauerhafte Änderung. Tools, die `stderr` exakt parsen (z. B. manche `jq`-Pipelines, Build-Tools mit `-o /dev/stderr`), können sich verhalten wie ein Prozess mit einer Pipe als stderr-Handle statt einem TTY. Meist unauffällig — aber gut zu wissen.
- **Still failures.** `false; echo $?` zeigt `1`, aber keine `stderr` — kein Erklär-Prompt.
- **Mehrzeilige Fehler.** Sehr lange Stacktraces werden 1:1 ans Modell gegeben. Codellama verkraftet ~16k Tokens Kontext, aber bei extremen Outputs kann die Antwort sehr lang werden.
- **Modellqualität.** Codellama 13b+ macht das ordentlich, kleinere Quantisierungen („q4_0" etc.) halluzinieren gelegentlich. Für präzise Antworten: größeres Modell oder llama3.1/Mistral.
- **Kein Internet.** Funktioniert vollständig offline, sobald das Modell einmal heruntergeladen ist.
- **Shell-spezifisch.** Nur Bash getestet. Zsh hat andere Trap/PROMPT_COMMAND-Semantik — Adaption möglich, aber nicht enthalten.

---

## Sicherheit & Datenschutz

- **Lokal, kein Cloud-Roundtrip.** Die Fehlermeldung geht ausschließlich an den lokalen Ollama-Daemon (Standard `127.0.0.1:11434`). Es werden keine Daten an Dritte übertragen.
- **Aber:** Fehlermeldungen enthalten oft Pfade, Usernamen, Token-Auszüge. Wenn dein lokales Ollama-Modell „telefoniert" (z. B. Telemetrie-aktiviertes Modell-Setup), könnten diese Inhalte nach außen gelangen. Standardinstallation: kein Telefonieren.
- **Shell-Expansion.** Der Befehl wird **nicht** evaluiert oder ausgeführt — nur als String an Ollama übergeben (über die Pipe). `$LAST_BASH_CMD` enthält den unverarbeiteten Text aus der DEBUG-Trap, der im Prompt-Aufbau eingesetzt wird. Bei sehr ungewöhnlichen Befehlen mit Sonderzeichen (Backticks, `$()`) könnten diese im Ollama-Output landen, aber niemals lokal ausgeführt werden.

---

## Mitmachen

Issues und PRs willkommen — siehe [GitHub-Repo](https://github.com/smlfg/bash-explain). Ideale Beiträge:

- **Alternative Modelle** als Default testen (Mistral, llama3.1)
- **Stille Fehler** ohne stderr behandeln
- **Mehrsprachigkeit** (Englisch, Französisch …) per `LANG`-Switch
- **Zsh-Adaption** als `bash-explain.zsh`
- **Tests:** Fake-Skripte, die saubere Exit-Codes und sauberes stderr produzieren, gegen `_explain_error` fahren

Bitte keine PRs, die das Tool produktiver machen wollen (Cloud-Calls, Telemetrie, persistente Logs) — das widerspricht dem Geist von „lokaler Lehrer, offline".

---

## Lizenz

[MIT](LICENSE) — siehe `LICENSE`-Datei. Copyright © 2026 Samuel Fleig.

---

## Autor

**Samuel Fleig** — [github.com/smlfg](https://github.com/smlfg)

Beigefügt im Rahmen der persönlichen Projektablage „Alles-was-lokale-Agencen-brauchen".
