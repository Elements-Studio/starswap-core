#!/bin/bash

move clean
move check 
move publish  --ignore-breaking-changes
move functional-test
move unit-test -g
