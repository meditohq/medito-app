#!/bin/sh

# Fixme in https://github.com/meditohq/medito-app/issues/151
echo "const BASE_URL = '$BASE_URL';" >> .env && \
echo "***REMOVED*** '$SENTRY_URL';" >> .env && \
echo "***REMOVED*** '$CONTENT_TOKEN';" >> .env && \
echo "***REMOVED*** '$INIT_TOKEN';" >> .env
