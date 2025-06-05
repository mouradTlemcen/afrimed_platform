#!/usr/bin/env bash
#
# Codex setup script: installs Flutter (stable) so dart/flutter commands work
set -e

echo "🔧  Installing system packages…"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -yq \
  git curl unzip xz-utils zip libglu1-mesa

echo "📦  Cloning Flutter (stable)…"
git clone --depth 1 --branch stable \
  https://github.com/flutter/flutter.git /opt/flutter

echo "🔑  Adding Flutter to PATH…"
echo 'export PATH=/opt/flutter/bin:"$PATH"' >> /etc/profile
export PATH=/opt/flutter/bin:"$PATH"

echo "📲  Running flutter doctor…"
flutter doctor -v

echo "✅  Flutter & Dart installed."

