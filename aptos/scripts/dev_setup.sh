#!/bin/bash
# Copyright (c) The Strcoin Core Contributors
# SPDX-License-Identifier: Apache-2.0
# This script sets up the environment for the Starcoin Move Framework build by installing necessary dependencies.
#
# Usage ./dev_setup.sh <options>
#   v - verbose, print all statements

# Assumptions for nix systems:
# 1 The running user is the user who will execute the builds.
# 2 .profile will be used to configure the shell
# 3 ${HOME}/bin/, or ${INSTALL_DIR} is expected to be on the path -etc.  will be installed there on linux systems.

# fast fail.
set -eo pipefail

APTOS_VERSION=1.0.1

SCRIPT_PATH="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_PATH/.." || exit

function usage {
  echo "Usage:"
  echo "Installs or updates necessary dev tools for starcoin move framework."
  echo "-p update ${HOME}/.profile"
  echo "-t install build tools"
  echo "This command must be called from the root folder of the starcoin-frame project."
}

function add_to_profile {
  eval "$1"
  FOUND=$(grep -c "$1" < "${HOME}/.profile" || true)  # grep error return would kill the script.
  if [ "$FOUND" == "0" ]; then
    echo "$1" >> "${HOME}"/.profile
  fi
}


# It is important to keep all path updates together to allow this script to work well when run in github actions
# inside of a docker image created using this script.   GHA wipes the home directory via docker mount options, so
# this profile needs built and sourced on every execution of a job using the docker image.   See the .github/actions/build-setup
# action in this repo, as well as docker/ci/github/Dockerfile.
function update_path_and_profile {
  touch "${HOME}"/.profile

  DOTNET_ROOT="$HOME/.dotnet"
  BIN_DIR="$HOME/bin"
  C_HOME="${HOME}/.cargo"
  if [[ "$OPT_DIR" == "true" ]]; then
    DOTNET_ROOT="/opt/dotnet"
    BIN_DIR="/opt/bin"
    C_HOME="/opt/cargo"
  fi

  mkdir -p "${BIN_DIR}"
  if [ -n "$CARGO_HOME" ]; then
    add_to_profile "export CARGO_HOME=\"${CARGO_HOME}\""
    add_to_profile "export PATH=\"${BIN_DIR}:${CARGO_HOME}/bin:\$PATH\""
  else
    add_to_profile "export PATH=\"${BIN_DIR}:${C_HOME}/bin:\$PATH\""
  fi
  if [[ "$INSTALL_PROVER" == "true" ]]; then
    add_to_profile "export DOTNET_ROOT=\"${DOTNET_ROOT}\""
    add_to_profile "export PATH=\"${DOTNET_ROOT}/tools:\$PATH\""
    add_to_profile "export Z3_EXE=\"${BIN_DIR}/z3\""
    add_to_profile "export CVC5_EXE=\"${BIN_DIR}/cvc5\""
    add_to_profile "export BOOGIE_EXE=\"${DOTNET_ROOT}/tools/boogie\""
  fi
}

# Install aptos CLI file,
function install_aptos_CLI {
  echo "Installing aptos CLI"
  VERSION="$(aptos --version || true)"
  if [ -n "$VERSION" ]; then
    if [[ "${BATCH_MODE}" == "false" ]]; then
      echo "aptos CLI is already installed, version: $VERSION"
    fi
  else
    if [[ $(uname -s) == "Darwin" ]]; then
      aptos_file="aptos-cli-${APTOS_VERSION}-MacOSX-x86_64";
    else
      if [ "$(. /etc/os-release; )" = "Ubuntu" ]; then
        if [[ $(lsb_release -r | cut -f 2) == '18.04' ]]; then
          echo "Unsupported OS version, only supported ubuntu 20 and later"
          exit 1
        else
          aptos_file="aptos-cli-${APTOS_VERSION}-Ubuntu-22.04-x86_64";
        fi
      else
        aptos_file="";
      fi
    fi

    work_dir=$(pwd)

    if [[ $aptos_file != "" ]]; then
      download_url="https://github.com/aptos-labs/aptos-core/releases/download/aptos-cli-v${APTOS_VERSION}/${aptos_file}.zip"
      curl -sL -o "${work_dir}/${aptos_file}.zip" ${download_url}
      unzip -q "${work_dir}/${aptos_file}.zip" -d "${INSTALL_DIR}"
      chmod +x "${INSTALL_DIR}aptos"
      rm "${work_dir}/${aptos_file}.zip"
    else
      echo "Unable to find CLI package, please check the version of aptos, Abort"
      exit 1
    fi
  fi
}

function welcome_message {
cat <<EOF
Welcome to Aptos Framework!

This script will download and install the necessary dependencies needed to
build, test and inspect Aptos Framework.

Based on your selection, these tools will be included:
EOF

  if [[ "$INSTALL_BUILD_TOOLS" == "true" ]]; then
cat <<EOF
Build tools (since -t or no option was provided):
  * aptos
EOF
  fi

  if [[ "$INSTALL_PROFILE" == "true" ]]; then
cat <<EOF
Moreover, ~/.profile will be updated (since -p was provided).
EOF
  fi

cat <<EOF
If you'd prefer to install these dependencies yourself, please exit this script
now with Ctrl-C.
EOF
}

BATCH_MODE=false;
VERBOSE=false;
INSTALL_BUILD_TOOLS=false;
INSTALL_PROFILE=false;
INSTALL_DIR="${HOME}/bin/"
OPT_DIR="false"

#parse args
while getopts "btopvysah:i:n" arg; do
  case "$arg" in
    b)
      BATCH_MODE="true"
      ;;
    t)
      INSTALL_BUILD_TOOLS="true"
      ;;
    p)
      INSTALL_PROFILE="true"
      ;;
    v)
      VERBOSE=true
      ;;
    y)
      INSTALL_PROVER="true"
      ;;
    n)
      OPT_DIR="true"
      ;;
    *)
      usage;
      exit 0;
      ;;
  esac
done

if [[ "$VERBOSE" == "true" ]]; then
	set -x
fi

if [[ "$INSTALL_BUILD_TOOLS" == "false" ]] && \
   [[ "$INSTALL_PROFILE" == "false" ]]; then
   INSTALL_BUILD_TOOLS="true"
fi

if [[ "${OPT_DIR}" == "true" ]]; then
  INSTALL_DIR="/opt/bin/"
fi
mkdir -p "$INSTALL_DIR" || true

PRE_COMMAND=()
if [ "$(whoami)" != 'root' ]; then
  PRE_COMMAND=(sudo)
fi

PACKAGE_MANAGER=
if [[ "$(uname)" == "Linux" ]]; then
  # check for default package manager for linux
  if [[ -f /etc/redhat-release ]]; then
    # use yum for redhat-releases by default
    if command -v yum &>/dev/null; then
      PACKAGE_MANAGER="yum"
    elif command -v dnf &>/dev/null; then
      # dnf is the updated default since Red Hat Enterprise Linux 8, CentOS 8, Fedora 22, and any distros based on these
      echo "WARNING: dnf package manager support is experimental"
      PACKAGE_MANAGER="dnf"
    fi
  elif [[ -f /etc/debian_version ]] && command -v apt-get &>/dev/null; then
    PACKAGE_MANAGER="apt-get"
  elif [[ -f /etc/arch-release ]] && command -v pacman &>/dev/null; then
    PACKAGE_MANAGER="pacman"
  elif [[ -f /etc/alpine-release ]] && command -v apk &>/dev/null; then
    PACKAGE_MANAGER="apk"
  fi
  # if no default OS specific PACKAGE_MANAGER detected, just pick one that's installed (as best effort)
  if [[ -z $PACKAGE_MANAGER ]]; then
    if command -v yum &>/dev/null; then
      PACKAGE_MANAGER="yum"
    elif command -v apt-get &>/dev/null; then
      PACKAGE_MANAGER="apt-get"
    elif command -v pacman &>/dev/null; then
      PACKAGE_MANAGER="pacman"
    elif command -v apk &>/dev/null; then
      PACKAGE_MANAGER="apk"
    elif command -v dnf &>/dev/null; then
      echo "WARNING: dnf package manager support is experimental"
      PACKAGE_MANAGER="dnf"
    else
      echo "Unable to find supported package manager (yum, apt-get, dnf, or pacman). Abort"
      exit 1
    fi
  fi
elif [[ "$(uname)" == "Darwin" ]]; then
  if command -v brew &>/dev/null; then
    PACKAGE_MANAGER="brew"
  else
    echo "Missing package manager Homebrew (https://brew.sh/). Abort"
    exit 1
  fi
else
  echo "Unknown OS. Abort."
  exit 1
fi

if [[ "$BATCH_MODE" == "false" ]]; then
    welcome_message
    printf "Proceed with installing necessary dependencies? (y/N) > "
    read -e -r input
    if [[ "$input" != "y"* ]]; then
	    echo "Exiting..."
	    exit 0
    fi
fi

if [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
	if [[ "$BATCH_MODE" == "false" ]]; then
    echo "Updating apt-get......"
  fi
	"${PRE_COMMAND[@]}" apt-get update
fi

if [[ "$INSTALL_PROFILE" == "true" ]]; then
  update_path_and_profile
fi

if [[ "$INSTALL_BUILD_TOOLS" == "true" ]]; then
  install_aptos_CLI
fi


if [[ "${BATCH_MODE}" == "false" ]]; then
cat <<EOF
Finished installing all dependencies.

You should now be able to build the project by running:
	aptos move build
EOF
fi

exit 0