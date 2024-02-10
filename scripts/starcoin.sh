#!/bin/bash
function usage() {
  echo -e "usage: astarcoin net"
  echo -e "net is main, barnard, proxima, halley"
  echo -e "to_dir like ~/.starcoin/main, ~/.starcoin/barnard, ~/.starcoin/proxima"
}

function connect_node() {
  net=$1
  account_dir=$2
  ws_url="ws://$net.seed.starcoin.org:9870"
  echo -e "starcoin --connect $ws_url --local-account-dir $account_dir console"
  starcoin --connect "$ws_url" --local-account-dir "$account_dir" console
}

if [ $# != 2 ]; then
  usage
  exit 1
fi
net=$1
to_dir=$2
account_dir="$to_dir/account_vaults"
case $net in
"main" | "barnard" | "proxima" |"halley")
  connect_node "$net" "$account_dir"
  ;;
*)
  echo "$net not supported"
  usage
  ;;
esac