#!/bin/bash

IPC=$1
WORK_DIR=$(pwd)

${WORK_DIR}/scripts/deploy/deploy_util.sh dev $IPC ${WORK_DIR}/scripts/deploy/commands_init_dev.cmd
${WORK_DIR}/scripts/deploy/deploy_util.sh dev $IPC ${WORK_DIR}/scripts/deploy/commands_init_swap.cmd
${WORK_DIR}/scripts/deploy/deploy_util.sh dev $IPC ${WORK_DIR}/scripts/deploy/commands_init_syrup.cmd