#!/bin/sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
REPO_DIR="$(CDPATH= cd -- "$PROJECT_DIR/../.." && pwd)"

cd "$PROJECT_DIR"
swift format lint --recursive Sources Tests
swift test
swift build -c release

if rg -n 'case .*=( )?"(command/exec|config/value/write|thread/delete|thread/archive)"' Sources; then
  echo "Forbidden RPC method found in application sources" >&2
  exit 1
fi

if rg -n 'hooks\.json' Sources Package.swift; then
  echo "Hook dependency found in native application" >&2
  exit 1
fi

test -f "$REPO_DIR/Schemas/AppServer-0.142.2/ServerRequest.json"
test -f "$REPO_DIR/Schemas/AppServer-0.144.1/ServerRequest.json"

echo "Codex Monitor checks passed"
