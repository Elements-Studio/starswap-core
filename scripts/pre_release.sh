#!/bin/bash

mpm package build
mpm package test
mpm spectest
mpm release

cd bridge-dep
mpm package build
mpm release