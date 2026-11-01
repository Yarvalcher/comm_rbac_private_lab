#!/usr/bin/env bash
# Lesson 0.2 proof: print the version of every tool the lab needs.
# Run from the repo root:  bash scripts/doctor.sh
# Exit code is 0 only if every tool is found and Python is 3.12.x.
set -u

fail=0

check() {  # check <label> <command...>  -> prints first line of output
  local label="$1"; shift
  local out
  if out=$("$@" 2>&1 | head -n 1) && [ -n "$out" ] && ! echo "$out" | grep -qi "not found\|not recognized"; then
    printf '%-10s %s\n' "$label" "$out"
  else
    printf '%-10s MISSING\n' "$label"
    fail=1
  fi
}

# Per-folder virtual envs (Windows uses Scripts/, Linux/macOS uses bin/); fall back to PATH.
pick() {  # pick <name> <venv-dir>
  local name="$1" dir="$2"
  for p in "$dir/.venv/Scripts/$name" "$dir/.venv/Scripts/$name.exe" "$dir/.venv/bin/$name"; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
  echo "$name"
}
DBT=$(pick dbt dbt)
SNOW=$(pick snow scripts)

PY=python
command -v python >/dev/null 2>&1 || PY=python3
command -v "$PY" >/dev/null 2>&1 || PY=py
# Prefer the Windows launcher's 3.12 when PATH puts another Python first.
if ! "$PY" --version 2>&1 | grep -q "^Python 3\.12\." && command -v py >/dev/null 2>&1; then
  PY312=$(py -3.12 -c "import sys; print(sys.executable)" 2>/dev/null | tr -d '\r')
  [ -n "$PY312" ] && PY="$PY312"
fi

check git       git --version
check openssl   openssl version
check python    "$PY" --version
check dbt       "$DBT" --version
check snow      "$SNOW" --version
check terraform terraform version
check docker    docker --version
check astro     astro version

# The plan pins Python 3.12.
if ! "$PY" --version 2>&1 | grep -q "^Python 3\.12\."; then
  echo "WARNING: Python is not 3.12.x"
  fail=1
fi

[ "$fail" -eq 0 ] && echo "All tools present." || echo "Some checks failed."
exit "$fail"
