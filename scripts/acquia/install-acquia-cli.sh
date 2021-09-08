#!/bin/sh

echo '\nPulling down and installing Acquia CLI to vendor/bin...'
cd vendor
git clone https://github.com/typhonius/acquia_cli.git
cd acquia_cli
git checkout 2.0.10
composer install
sed -i 's/vendor//' .gitignore
ln -s ../acquia_cli/bin/acquiacli ../bin/acquiacli
ln -s ../../acquiacli.yml ./acquiacli.yml
cd ../../
