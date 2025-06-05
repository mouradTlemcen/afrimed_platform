#!/usr/bin/env bash
set -e

echo "🔧  Installing system packages…"

if command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -yq \
    git curl unzip xz-utils zip libstdc++ libglu1-mesa
elif command -v apk >/dev/null 2>&1; then
  apk update
  apk add --no-cache \
    git curl unzip xz zip libstdc++ mesa-glu
else
  echo "⚠️  No apt-get or apk found; assuming git & curl already present."
fi
echo "📦  Cloning Flutter (stable)…"
git clone --depth 1 --branch stable \
  https://github.com/flutter/flutter.git /opt/flutter

echo "🔑  Adding Flutter to PATH…"
echo 'export PATH=/opt/flutter/bin:"$PATH"' >> /etc/profile
export PATH=/opt/flutter/bin:"$PATH"

echo "📲  Running flutter doctor…"
flutter doctor -v

echo "✅  Flutter & Dart installed."

