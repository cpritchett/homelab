#!/bin/sh
# Load API keys from media.env (written by op-secrets)
set -a
[ -f /secrets/media.env ] && . /secrets/media.env
set +a

# Generate config from template with env var substitution
mkdir -p /app/config
python -c "
import os, re, pathlib
t = pathlib.Path('/config.yaml.template').read_text()
t = re.sub(r'\\\$\{(\w+)\}', lambda m: os.environ.get(m.group(1), m.group(0)), t)
pathlib.Path('/app/config/config.yaml').write_text(t)
"

exec python main.py
