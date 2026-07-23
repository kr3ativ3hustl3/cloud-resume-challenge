#!/usr/bin/env bash
# Packages counter.py into a zip that Terraform will deploy to Lambda.
#
# Run this BEFORE `terraform apply`, and again any time counter.py
# changes. This is a deliberately manual, provider-free step — see
# docs/troubleshooting.md for why (older macOS systems can't run some
# newer Terraform provider plugin binaries, e.g. `archive` or `null`).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$SCRIPT_DIR/../../terraform/modules/counter-api/counter.zip"

cd "$SCRIPT_DIR"
rm -f "$OUTPUT"
zip -j "$OUTPUT" counter.py

echo "Built $OUTPUT"
