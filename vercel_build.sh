#!/bin/bash
set -e

echo "=== Installing Flutter ==="
git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/flutter
export PATH="$PATH:/opt/flutter/bin"

echo "=== Flutter version ==="
flutter --version

echo "=== Installing dependencies ==="
flutter pub get

echo "=== Building Flutter Web ==="
flutter build web --release

echo "=== Build complete ==="
ls build/web
