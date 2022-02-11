#!/bin/bash

## 1. local startup a dev/proxima/barnard node
## 2. Copy ipc file path
## 3. run this script, pass the ipc file path.
IPC=$1
WORK_DIR=$(pwd)

${WORK_DIR}/scripts/deploy/deploy_util.sh dev $IPC ${WORK_DIR}/scripts/deploy/commands_init_dev.cmd
if [ $? -ne 0 ]; then
  exit 1
fi

${WORK_DIR}/scripts/deploy/deploy_util.sh dev $IPC ${WORK_DIR}/scripts/deploy/commands_init_swap.cmd
if [ $? -ne 0 ]; then
  exit 1
fi

${WORK_DIR}/scripts/deploy/deploy_util.sh dev $IPC ${WORK_DIR}/scripts/deploy/commands_init_syrup.cmd
if [ $? -ne 0 ]; then
  exit 1
fi