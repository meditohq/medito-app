#!/bin/sh

# Fixme in https://github.com/meditohq/medito-app/issues/151
echo "const BASE_URL = '$BASE_URL';" >> .env && \
echo "const SENTRY_URL = '$SENTRY_URL';" >> .env && \
echo "const CONTENT_TOKEN = '$CONTENT_TOKEN';" >> .env && \
echo "const INIT_TOKEN = '$INIT_TOKEN';" >> .env
