#!/bin/bash

KEY="ai-automation-key"
USER="ubuntu"
SERVER="public_ip"
REMOTE_DIR="/home/ubuntu/"

# copy folders recursively and files from the local server to the remote server
scp -r -i terraform/key-pair/"$KEY" \
docker-compose.yml \
"$USER"@"$SERVER":"$REMOTE_DIR"
