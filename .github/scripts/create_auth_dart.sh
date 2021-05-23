#!/bin/sh

# Fixme in https://github.com/meditohq/medito-app/issues/151
echo "const BASE_URL = '$BASE_URL';" >> lib/network/auth.dart && \
echo "***REMOVED*** '$SENTRY_URL';" >> lib/network/auth.dart && \
echo "***REMOVED*** '$CONTENT_TOKEN';" >> lib/network/auth.dart && \
echo "***REMOVED*** '$INIT_TOKEN';" >> lib/network/auth.dart
