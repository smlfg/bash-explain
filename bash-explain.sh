#!/bin/bash
# Automatische Fehler-Erklärung für Bash-Befehle
# Source this in .bashrc: source ~/bin/bash-explain.sh

# Temporäre Datei für stderr pro Shell-Session
export BASH_ERROR_FILE="/tmp/bash_stderr_$$"
> "$BASH_ERROR_FILE"

# Cleanup bei Shell-Exit
trap 'rm -f "$BASH_ERROR_FILE"' EXIT

# Stderr umleiten UND anzeigen (via tee)
exec 2> >(tee "$BASH_ERROR_FILE" >&2)

# Letzten Befehl speichern
trap 'LAST_BASH_CMD=$BASH_COMMAND' DEBUG

# Nach jedem Befehl prüfen ob Fehler
_explain_error() {
    local exit_code=$?

    # Nur bei Fehler und wenn stderr nicht leer
    if [ $exit_code -ne 0 ] && [ -s "$BASH_ERROR_FILE" ]; then
        local error_output
        error_output=$(cat "$BASH_ERROR_FILE")

        # Datei leeren für nächsten Befehl
        > "$BASH_ERROR_FILE"

        # Kleine Pause damit stderr fertig geschrieben ist
        sleep 0.1

        echo ""
        echo "💡 Erklärung:"
        echo -e "Du bist ein geduldiger Linux-Lehrer für Anfänger.

Befehl: $LAST_BASH_CMD
Fehler: $error_output

Erkläre in 2-3 kurzen Sätzen auf Deutsch:
1. Was ist passiert?
2. Wie behebe ich es?

Keine Code-Blöcke, nur Text." | ollama run codellama --nowordwrap
    else
        # Datei leeren auch bei Erfolg
        > "$BASH_ERROR_FILE" 2>/dev/null
    fi
}

# An PROMPT_COMMAND anhängen
PROMPT_COMMAND="_explain_error${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

echo "🎓 Bash-Erklärer aktiv. Fehler werden automatisch erklärt."
