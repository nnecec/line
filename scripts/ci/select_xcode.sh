#!/usr/bin/env bash

set -euo pipefail

selected_xcode=""
for candidate in \
  /Applications/Xcode_26.4.app \
  /Applications/Xcode_26.4.1.app \
  /Applications/Xcode_26.5.app \
  /Applications/Xcode_26.6.app; do
  if [[ -d "$candidate" ]]; then
    selected_xcode="$candidate"
    sudo xcode-select -s "$candidate"
    break
  fi
done

if [[ -z "$selected_xcode" ]]; then
  selected_xcode=$(xcode-select -p)
fi

xcode_version_output=$(xcodebuild -version)
printf '%s\n' "$xcode_version_output"

xcode_version=$(awk '/^Xcode / { print $2; exit }' <<< "$xcode_version_output")
xcode_build=$(awk '/^Build version / { print $3; exit }' <<< "$xcode_version_output")
if [[ "$xcode_version" != 26.* || -z "$xcode_build" ]]; then
  echo "::error::Line requires Xcode 26; selected developer directory: $selected_xcode"
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'cache_key=%s-%s\n' "$xcode_version" "$xcode_build" >> "$GITHUB_OUTPUT"
fi
