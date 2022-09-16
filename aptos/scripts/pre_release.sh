#!/bin/bash

mpm package build
mpm package test
mpm integration-test
mpm release