#!/bin/bash

net=$1
ipc_file=$2
script_file=$3

exec_commands=()

function exec_script() {
  if [ "${net}" == "" ]
  then
    echo 'Network not specified! exit!'
    exit 1
  elif [ "${ipc_file}" == "" ]
    then
      echo 'Ipc file not specified! exit!'
      exit 1
  elif [ "${script_file}" == "" ]
      then
        echo 'Script file not specified! exit!'
        exit 1
  fi

  while IFS= read -r line; do
     exec_commands+=("$line")
  done <$script_file

  move clean && move check && move publish --ignore-breaking-changes

  for sub_command in "${exec_commands[@]}"
  do
    if [ "${sub_command:0:1}" != "#" ] && [ ${#sub_command} -ne 0 ]
    then
      respo=$(starcoin --net ${net} --connect $ipc_file $sub_command)

      if [[ 'dry run failed' == *"${respo}"* ]]; then
        echo "Dry run failed, command: $sub_command, file: $script_file"
        exit 1
      elif [[ 'error' == *"${respo}"* ]]; then
        echo "Execute generate error, command: $sub_command, file: $script_file"
        exit 1
      fi
    fi
  done

  echo "All deployment has executed for $script_file"
}

exec_script