#!/bin/sh

# Fixme in https://github.com/meditohq/medito-app/issues/151
echo "const BASE_URL = '$BASE_URL';" >> lib/.env && \
echo "***REMOVED*** '$SENTRY_URL';" >> lib/.env && \
echo "***REMOVED*** '$CONTENT_TOKEN';" >> lib/.env && \
echo "***REMOVED*** '$INIT_TOKEN';" >> lib/.env
