#!/bin/sh

echo '\nPulling down and installing Acquia CLI to vendor/bin...'
cd vendor/bin
curl -Lo acli https://github.com/acquia/cli/releases/download/1.30.1/acli.phar
chmod +x acli
