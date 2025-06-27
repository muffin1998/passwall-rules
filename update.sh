#!/bin/sh

SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)

echo "shell foler: $SHELL_FOLDER"
chmod +x ${SHELL_FOLDER}/fetch.sh
chmod +x ${SHELL_FOLDER}/generate.sh
chmod +x ${SHELL_FOLDER}/init.sh

${SHELL_FOLDER}/fetch.sh
${SHELL_FOLDER}/generate.sh
${SHELL_FOLDER}/init.sh

