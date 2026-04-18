# Login shell env (keep minimal)

# Homebrew env (Apple Silicon + Intel)
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# Conda bootstrap (minimal)
if [[ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]]; then
  . "$HOME/miniforge3/etc/profile.d/conda.sh"
fi
