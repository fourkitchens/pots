#!/bin/sh


# Functions checking if version is less than another in bash.
# @see https://stackoverflow.com/a/4024263/658023
verlte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

verlt() {
    [ "$1" = "$2" ] && return 1 || verlte $1 $2
}

echo '\nPulling down and installing Acquia CLI to vendor/bin...'
cd vendor/bin
PHP_VERSION=$(php -r "echo PHP_VERSION;")
echo "PHP $PHP_VERSION is installed on this environment."
# If php is Less than 8, install the PHP 7 version of acli
if verlt "$PHP_VERSION" "8.0.0"; then
  echo "Downloading PHP 7 version."
  curl -Lo acli https://github.com/acquia/cli/releases/download/1.30.1/acli.phar
else
  echo "Downloading PHP 8 version."
  curl -Lo acli https://github.com/acquia/cli/releases/latest/download/acli.phar
fi

chmod +x acli
