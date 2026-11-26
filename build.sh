#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 scripts/icons.py
chmod +x cmd/*
fnpack build
