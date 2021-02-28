#!/bin/bash
set -e
export NIGHT_SHEEP_API_PORT=${1-8080}

cat deploy-api.yaml | envsubst '${NIGHT_SHEEP_API_PORT}' | tee -a deploy.log  | kubectl apply -f -
