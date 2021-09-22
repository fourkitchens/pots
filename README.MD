# Circle CI Starter for Projects

This Composer package provides the starts for what you need to test and deploy
an hosted site on something like Acquia.

## Installation

1. Install the package and copy over the template config.yml

    ```
    composer require fourkitchens/project_ci
    mkdir .circleci
    cp vendor/fourkitchens/project_ci/config.yml .circleci/config.yml
    ```
2. Set up your circleci project to with the required environment variables

    **TODO: Make this not Acquia specific.**

    ```
    # Required environmental variables should be set via the CircleCI web interface:
    #
    # - ACQUIA_CANONICAL_ENV
    #     Environment to get database from. Usually "prod".
    # - ACQUIA_REALM
    #     Cloud API Realm. Usually "prod" or "devcloud".
    #     See: https://docs.acquia.com/acquia-cloud/api#realm
    # - ACQUIA_SITE
    #     Cloud API Site parameter.
    # - ACQUIA_REPO
    #     Acquia git repo url.
    # - ACQUIA_BOT_EMAIL
    #     Email used to commit deployment commits.
    # - ACQUIA_BOT_NAME
    #     Display name use for the deployment committer.
    # - ACQUIACLI_KEY
    #     Cloud API Private key generated when you generate a token.
    #     Used in creating and getting backups and other Acquia Cloud actions.
    #     See: https://github.com/typhonius/acquia_cli#generating-an-api-access-token
    # - ACQUIACLI_SECRET
    #     Cloud API secret generated when you generate a token.
    ```
3. Customize any scripts by copying a script from `./vendor/fourkitchens/project_ci/scripts` to `.circleci/scripts`
4. Customize the web root directory if you must by changing all instances of `default: "docroot"` to the value you need.
5. Make sure you have a `.nvmrc` file with a valid verison of node at the root
   of the project.
