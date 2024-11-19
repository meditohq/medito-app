#!/bin/sh

echo "const BASE_URL = '$BASE_URL';" >> .prod.env && \
echo "const INIT_TOKEN = '$INIT_TOKEN';" >> .prod.env
echo "const BASE_URL = '$BASE_URL';" >> .staging.env && \
echo "const INIT_TOKEN = '$INIT_TOKEN';" >> .staging.env
