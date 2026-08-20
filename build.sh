#!/bin/bash
set -e

# Clonar Flutter en Vercel
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter
fi

export PATH="$PATH:`pwd`/flutter/bin"

flutter doctor
flutter build web --release --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY