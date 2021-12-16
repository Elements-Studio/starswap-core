#!/bin/bash

move clean
move check --starcoin-rpc http://barnard.seed.starcoin.org:9850 --mode starcoin
move publish  --ignore-breaking-changes
