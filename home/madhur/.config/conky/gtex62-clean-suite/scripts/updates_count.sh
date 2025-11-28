#!/usr/bin/env bash
# Prints a single integer = available updates (APT + Flatpak if present)

# APT updates (skip the "Listing..." header regardless of language by skipping NR==1)
apt_count=$(apt list --upgradeable 2>/dev/null | awk 'NR>1{c++} END{print c+0}')

# Flatpak updates (optional; 0 if flatpak not installed)
if command -v flatpak >/dev/null 2>&1; then
  fp_count=$(flatpak remote-ls --updates 2>/dev/null | wc -l)
else
  fp_count=0
fi

echo $((apt_count + fp_count))
