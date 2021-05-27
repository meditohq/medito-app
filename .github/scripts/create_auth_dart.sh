#!/bin/sh

# Fixme in https://github.com/meditohq/medito-app/issues/151
echo "const BASE_URL = '$BASE_URL';" >> lib/network/auth.dart && \
echo "const SENTRY_URL = '$SENTRY_URL';" >> lib/network/auth.dart && \
echo "const CONTENT_TOKEN = '$CONTENT_TOKEN';" >> lib/network/auth.dart && \
echo "const INIT_TOKEN = '$INIT_TOKEN';" >> lib/network/auth.dart
