#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
godot --headless --path "$project_dir" --editor --import --quit
godot --headless --path "$project_dir" --export-release Web "$project_dir/../godot.html"
