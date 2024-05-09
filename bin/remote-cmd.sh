#!/usr/bin/env bash

#
# usage: ./exec host.example.com 'ap-get update && apt-get install gcc'
#


valid_ipv4() {
    local ip="$1"
    err_msg='IP address is invalid'
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "$err_msg"; return 1; }
    for i in ${ip//./ }; do
        [[ "${#i}" -gt 1 && "${i:0:1}" == 0 ]] && { echo "$err_msg"; return 1; }
        [[ "$i" -gt 255 ]] && { echo "$err_msg"; return 1; }
    done
    echo 'IP address is valid'
}

set -e

Bin="$(cd -- "$(dirname "$0")" && pwd)"
SSH_HOST=$1
SCRIPT_TO_RUN=$2
FORCE=$3

echo "Starting exec of '$SCRIPT_TO_RUN' on '$SSH_HOST'"

if [ -z "$SSH_HOST" ]; then
  echo "Missing host"
  exit 1
fi

IS_IP=$(valid_ipv4 $SSH_HOST || :)

if [ "$IS_IP" == "IP address is invalid" ]; then
  HOST_IP=$(dig +short $SSH_HOST)
  if [ -z $HOST_IP ]; then
    echo "unable to find ip address for $SSH_HOST"
    exit 2
  else
    echo "Shipping to $SSH_HOST=$HOST_IP"
    SSH_HOST=$HOST_IP
  fi
else
  echo "is valid ip: '$IS_IP'"
fi

if [ -z "$SCRIPT_TO_RUN" ]; then
  echo "Missing script"
  exit 3
fi

echo "ssh root@$SSH_HOST \\
  -p 22 \\
  -o StrictHostKeyChecking=no \\
  \"$SCRIPT_TO_RUN\""

if [ -n "$FORCE" ]; then
  ssh root@$SSH_HOST \
    -p 22 \
    -o StrictHostKeyChecking=no \
    "$SCRIPT_TO_RUN"
else
  read -p "Are you sure? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh root@$SSH_HOST \
      -p 22 \
      -o StrictHostKeyChecking=no \
      "$SCRIPT_TO_RUN"
  else
    echo "Aborted"
  fi
fi



exit $?
