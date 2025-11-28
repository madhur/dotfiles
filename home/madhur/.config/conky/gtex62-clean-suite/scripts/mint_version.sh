#!/usr/bin/env bash
# Prints "Linux Mint 22.2 (Wilma)" or falls back gracefully.

if [ -r /etc/linuxmint/info ]; then
  # Mint-specific: get RELEASE and CODENAME
  REL=$(awk -F= '/^RELEASE=/{gsub(/"/,"");print $2}' /etc/linuxmint/info)
  CODE=$(awk -F= '/^CODENAME=/{gsub(/"/,"");print $2}' /etc/linuxmint/info)
  if [ -n "$REL" ]; then
    if [ -n "$CODE" ]; then
      echo "Linux Mint $REL ($CODE)"
    else
      echo "Linux Mint $REL"
    fi
    exit 0
  fi
fi

# Generic fallback via os-release
if [ -r /etc/os-release ]; then
  NAME=$(awk -F= '/^NAME=/{gsub(/"/,"");print $2}' /etc/os-release)
  VER=$(awk -F= '/^VERSION_ID=/{gsub(/"/,"");print $2}' /etc/os-release)
  if [ -n "$NAME" ] || [ -n "$VER" ]; then
    echo "$NAME ${VER}"
    exit 0
  fi
fi

# Last resort
echo "Linux Mint"
