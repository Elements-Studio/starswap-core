#!/bin/bash

# Copyright (c) The Strcoin Core Contributors
# SPDX-License-Identifier: Apache-2.0

set -e

MODULE_NAME=$1
SCRIPT_PATH="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_PATH/../$MODULE_NAME" || exit

aptos move compile
aptos move test