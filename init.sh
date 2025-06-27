#!/bin/sh

SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)

rm -r /var/run/proxy
cp -r $SHELL_FOLDER/output /var/run/proxy