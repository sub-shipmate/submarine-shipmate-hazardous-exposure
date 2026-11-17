#!/usr/bin/env bash
set -e
echo "=== VERIFY ARCHIVE ==="
python3 references/scripts/archive_public_references.py
echo
echo "=== ARCHIVE TREE ==="
find references/public-archive -maxdepth 2 -type f -printf '%p\t%k KB\n' | sort
echo
echo "=== INVENTORY ==="
ls -lh references/archive-inventory.csv
echo
echo "=== GIT STATUS ==="
git status --short references/ || true
