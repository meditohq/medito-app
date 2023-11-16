#!/bin/sh

# Fixme in https://github.com/meditohq/medito-app/issues/151
echo "const BASE_URL = '$BASE_URL';" >> /.prod.env && \
echo "const SENTRY_URL = '$SENTRY_URL';" >> /.prod.env && \
echo "const INIT_TOKEN = '$INIT_TOKEN';" >> /.prod.env
