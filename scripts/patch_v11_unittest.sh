#!/usr/bin/env bash
# Patch StarcoinFramework v11 UnitTest naming for mpm v1.13.20 compatibility.
#
# mpm v1.13.20 expects `std::unit_test` (v12 naming), but the v11 framework
# provides `Std::UnitTest` (uppercase). This script patches the mpm cache
# so that `mpm package test` works with v11 framework.
#
# Run once after cloning or after clearing ~/.move cache.
set -euo pipefail

FRAMEWORK_REV="198d236f071819257ebdf54ed4502099a7daaaf5"
CACHE_DIR="$HOME/.move/https___github_com_starcoinorg_starcoin-framework_git_${FRAMEWORK_REV}"
UT_DIR="${CACHE_DIR}/unit-test"

if [[ ! -d "$UT_DIR" ]]; then
    echo "Cache not found: $UT_DIR"
    echo "Run 'mpm package build' first to populate the cache, then re-run this script."
    exit 1
fi

# Check if already patched
if grep -q 'std="0x1"' "$UT_DIR/Move.toml" 2>/dev/null; then
    echo "Already patched."
    exit 0
fi

echo "Patching v11 UnitTest: Std → std, UnitTest → unit_test ..."
sed -i.bak 's/Std="0x1"/std="0x1"/' "$UT_DIR/Move.toml"
sed -i.bak 's/module Std::UnitTest/module std::unit_test/' "$UT_DIR/sources/UnitTest.move"
rm -f "$UT_DIR/Move.toml.bak" "$UT_DIR/sources/UnitTest.move.bak"
echo "Done. You can now run 'mpm package test'."
