#!/usr/bin/env bash

#
# Copyright (c) 2024 Ocean Protocol contributors
# SPDX-License-Identifier: Apache-2.0
#

validate_hex() {
  if [[ ! "$1" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
    echo "The private key seems invalid, exiting ..."
    exit 1
  fi
}

validate_address() {
  if [[ ! "$1" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    echo "Invalid wallet address, exiting!"
    exit 1
  fi
}

validate_port() {
  if [[ ! "$1" =~ ^[0-9]+$ ]] || [ "$1" -le 1024 ] || [ "$1" -ge 65535 ]; then
    echo "Invalid port number, it must be between 1024 and 65535."
    exit 1
  fi
}

validate_ip_or_fqdn() {
  local input=$1

  if [[ "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    IFS='.' read -r -a octets <<< "$input"
    for octet in "${octets[@]}"; do
      if (( octet < 0 || octet > 255 )); then
        echo "Invalid IPv4 address. Each octet must be between 0 and 255."
        return 1
      fi
    done

    if [[ "$input" =~ ^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\.|^169\.254\.|^100\.64\.|^198\.51\.100\.|^203\.0\.113\.|^224\.|^240\. ]]; then
      echo "The provided IP address belongs to a private or non-routable range and might not be accessible from other nodes."
      return 1
    fi
  elif [[ "$input" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    return 0
  else
    echo "Invalid input, must be a valid IPv4 address or FQDN."
    return 1
  fi

  return 0
}

# Fetch public IP automatically
get_public_ip() {
  echo "Fetching public IPv4 address..."
  PUBLIC_IP=$(curl -s ifconfig.me)
  if validate_ip_or_fqdn "$PUBLIC_IP"; then
    echo "Detected public IPv4 address: $PUBLIC_IP"
  else
    echo "Failed to detect a valid public IPv4 address."
    exit 1
  fi
}

read -p "Do you have your private key for running the Ocean Node [ y/n ]: " has_key

if [ "$has_key" == "y" ]; then
  read -p "Enter your private key: " PRIVATE_KEY
  validate_hex "$PRIVATE_KEY"
else
  read -p "Do you want me to create a private key for you [ y/n ]: " create_key
  if [ "$create_key" == "n" ]; then
    echo "Exiting! Private Key is a mandatory variable"
    exit 1
  fi
  
  echo "Generating Private Key, please wait..."
  output=$(head -c 32 /dev/urandom | xxd -p | tr -d '\n' | awk '{print "0x" $0}')
  PRIVATE_KEY=$(echo "$output")
  echo -e "Generated Private Key: \e[1;31m$PRIVATE_KEY\e[0m" 
  validate_hex "$PRIVATE_KEY"
fi

read -p "Please provide the wallet address to be added as Ocean Node admin account: " ALLOWED_ADMINS
validate_address "$ALLOWED_ADMINS"

echo -ne "Provide the HTTP_API_PORT value or accept the default (press Enter) [\e[1;32m8000\e[0m]: "
read HTTP_API_PORT
HTTP_API_PORT=${HTTP_API_PORT:-8000}
validate_port "$HTTP_API_PORT"

echo -ne "Provide the P2P_ipV4BindTcpPort or accept the default (press Enter) [\e[1;32m9000\e[0m]: "
read P2P_ipV4BindTcpPort
P2P_ipV4BindTcpPort=${P2P_ipV4BindTcpPort:-9000}
validate_port "$P2P_ipV4BindTcpPort"

echo -ne "Provide the P2P_ipV4BindWsPort or accept the default (press Enter) [\e[1;32m9001\e[0m]: "
read P2P_ipV4BindWsPort
P2P_ipV4BindWsPort=${P2P_ipV4BindWsPort:-9001}
validate_port "$P2P_ipV4BindWsPort"

echo -ne "Provide the P2P_ipV6BindTcpPort or accept the default (press Enter) [\e[1;32m9002\e[0m]: "
read P2P_ipV6BindTcpPort
P2P_ipV6BindTcpPort=${P2P_ipV6BindTcpPort:-9002}
validate_port "$P2P_ipV6BindTcpPort"

echo -ne "Provide the P2P_ipV6BindWsPort or accept the default (press Enter) [\e[1;32m9003\e[0m]: "
read P2P_ipV6BindWsPort
P2P_ipV6BindWsPort=${P2P_ipV6BindWsPort:-9003}
validate_port "$P2P_ipV6BindWsPort"

# Automatically fetch public IPv4 or ask the user for FQDN
read -p "Do you want me to automatically detect your public IPv4 address? [ y/n ]: " auto_detect
if [ "$auto_detect" == "y" ]; then
  get_public_ip
  P2P_ANNOUNCE_ADDRESS="$PUBLIC_IP"
else
  read -p "Provide the public IPv4 address or FQDN where this node will be accessible: " P2P_ANNOUNCE_ADDRESS
  validate_ip_or_fqdn "$P2P_ANNOUNCE_ADDRESS"
  if [ $? -ne 0 ]; then
    echo "Invalid address. Exiting!"
    exit 1
  fi
fi

if [[ "$P2P_ANNOUNCE_ADDRESS" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  # IPv4
  P2P_ANNOUNCE_ADDRESSES='["/ip4/'$P2P_ANNOUNCE_ADDRESS'/tcp/'$P2P_ipV4BindTcpPort'", "/ip4/'$P2P_ANNOUNCE_ADDRESS'/ws/tcp/'$P2P_ipV4BindWsPort'"]'
elif [[ "$P2P_ANNOUNCE_ADDRESS" =~ ^[a-zA-Z0-9.-]+$ ]]; then
  # FQDN
  P2P_ANNOUNCE_ADDRESSES='["/dns4/'$P2P_ANNOUNCE_ADDRESS'/tcp/'$P2P_ipV4BindTcpPort'", "/dns4/'$P2P_ANNOUNCE_ADDRESS'/ws/tcp/'$P2P_ipV4BindWsPort'"]'
fi

# The rest of the script remains unchanged
