#!/usr/bin/env bash
#export JUPYTER_NOTEBOOK_DIR="/path/to/your/notebooks"
set -e

VENV_ACTIVATE="$HOME/venvs/jupyter/bin/activate"
: "${JUPYTER_NOTEBOOK_DIR:?set JUPYTER_NOTEBOOK_DIR to the notebook directory}"

source "$VENV_ACTIVATE"
cd "$JUPYTER_NOTEBOOK_DIR"

# Force a new browser window when JUPYTER_BROWSER_APP is set (macOS).
# Example: export JUPYTER_BROWSER_APP="Google Chrome"
if [[ -n "${JUPYTER_BROWSER_APP:-}" ]]; then
  export JUPYTER_BROWSER="open -n -a \"${JUPYTER_BROWSER_APP}\" --args --new-window"
fi

exec jupyter lab "$@"
