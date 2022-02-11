#!/bin/bash

##
## 1. local startup a dev/proxima/barnard node
## 2. Copy ipc file path
## 3. run this script, pass the ipc file path.
##
## eg: ./scripts/auto_deploy.sh /var/folders/yl/1jwdcrx91p96yh8c0yw03x280000gn/T/5d0f92950052e50d78fd7654e10e5481/dev/starcoin.ipc
##
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