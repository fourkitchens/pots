<?php

// Takes 2 arguments.
// 1) git branch being worked on
// 2) json file housing the mapping

// From these 2 arguments, we derive some environment variables that will help
// us deploy. We check the mapping's branches to see what environment settings
// we should be deploying to.

if (isset($argc)) {
  if (isset($argv[1]) && isset($argv[2])) {
    $branch = $argv[1];
    $json_filename = $argv[2];
    $mapping = json_decode(file_get_contents($json_filename), TRUE);
    foreach ($mapping as $env => $properties) {
      if ($branch == $properties['branch']) {
        break;
      }
      else if (preg_match("/^\/.+\/[a-z]*$/i", $properties['branch'])) {
        // The branch is a regex... so lets check it.
        if (preg_match($properties['branch'], $branch)) {
          $break;
        }
      }
    }
    echo <<<EOF
HOSTING_MAPPING_ENV="$env"
HOSTING_MAPPING_SSH_USER="{$properties['ssh_user']}"
HOSTING_MAPPING_SSH_HOST="{$properties['ssh_host']}"
HOSTING_MAPPING_SSH_PORT="{$properties['ssh_port']}"
HOSTING_MAPPING_SSH_OPTIONS="{$properties['ssh_options']}"
HOSTING_MAPPING_PATH="{$properties['path']}"
EOF;
  }
}
