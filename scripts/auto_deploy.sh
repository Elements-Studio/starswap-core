#!/bin/bash

##
## 1. local startup a dev/proxima/barnard node
## 2. Copy ipc file path
## 3. run this script, pass the ipc file path.
##
## eg:
##    ./scripts/auto_deploy.sh /var/folders/yl/1jwdcrx91p96yh8c0yw03x280000gn/T/5d0f92950052e50d78fd7654e10e5481/dev/starcoin.ipc dev
##
##
IPC=$1
NET=$2
WORK_DIR=$(pwd)

function check_result() {
  if [ $? -ne 0 ]; then
    exit 1
  fi
}

${WORK_DIR}/scripts/pre_release.sh
check_result

${WORK_DIR}/scripts/deploy/deploy_util.sh ${NET} $IPC ${WORK_DIR}/scripts/deploy/${NET}/init_account.cmd
check_result

${WORK_DIR}/scripts/deploy/deploy_util.sh ${NET} $IPC ${WORK_DIR}/scripts/deploy/${NET}/swap.cmd
check_result

${WORK_DIR}/scripts/deploy/deploy_util.sh ${NET} $IPC ${WORK_DIR}/scripts/deploy/${NET}/swap_farm.cmd
check_result

${WORK_DIR}/scripts/deploy/deploy_util.sh ${NET} $IPC ${WORK_DIR}/scripts/deploy/${NET}/swap_syrup.cmd
check_result