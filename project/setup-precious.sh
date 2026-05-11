#!/usr/bin/env bash
# Convenience helper for the Blast Radius Test lab.
# Sets up ~/precious/ on the host with three sample files.
set -e

mkdir -p ~/precious
echo "Q4 forecast: confidential" > ~/precious/forecast.txt
echo "DB_PASSWORD=do-not-leak"   > ~/precious/credentials.env
echo "// proprietary algorithm"  > ~/precious/source.code

echo "Set up ~/precious/ with 3 sample files:"
ls -la ~/precious/
echo
echo "Full host path: $(cd ~/precious && pwd)"
echo
echo "Note this path. The sandbox will try to reach it in Step 9 — and fail."
