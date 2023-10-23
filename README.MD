# Circle CI Starter for Projects

This Composer package provides the starts for what you need to test and deploy
a hosted site on something like Acquia.

## TOC

* [Upgrading](#upgrading)
* [Dependencies](#dependencies)
* [Installation](#installation)
* [Configure Environment](#configure-environment)
   + [Shared](#shared)
      - [Deploy Bot Setup](#deploy-bot-setup)
         * [Create a GitHub Account for the Deploy Bot](#create-a-github-account-for-the-deploy-bot)
      - [Configure an SSH Key](#configure-an-ssh-key)
      - [Get a Github Token](#get-a-github-token)
      - [Configure Environment Variables](#configure-environment-variables)
   + [Pantheon](#pantheon)
      - [Create a Pantheon Account for your Deploy Bot](#create-a-pantheon-account-for-your-deploy-bot)
      - [Set up SSH Key](#set-up-ssh-key)
      - [Get a Terminus Token (or Machine Token)](#get-a-terminus-token-or-machine-token)
      - [Configure More CircleCi Environment Variables](#configure-more-circleci-environment-variables)
   + [Acquia](#acquia)
      - [Create an Acquia Account for your Deploy Bot](#create-an-acquia-account-for-your-deploy-bot)
      - [Set up SSH Key](#set-up-ssh-key-1)
      - [Configure More CircleCi Environment Variables](#configure-more-circleci-environment-variables-1)
* [Configure CircleCI config.yml](#configure-circleci-configyml)
   + [Pipeline Parameter Defaults](#pipeline-parameter-defaults)
      - [php-version](#php-version)
      - [tz](#tz)
      - [host-variant](#host-variant)
         * [pantheon](#pantheon)
         * [acquia](#acquia)
         * [general](#general)
      - [docroot](#docroot)
      - [artifact_workspace](#artifact_workspace)
   + [Other Configuration](#other-configuration)
      - [persisting_dirs](#persisting_dirs)
* [Configurable Environment Variables](#configurable-environment-variables)
   + [Shared](#shared-1)
   + [Pantheon Specific](#pantheon-specific)
   + [Acquia Specific](#acquia-specific)
* [Helper Environment Variables](#helper-environment-variables)
* [Configure Composer.json](#configure-composerjson)
* [Configure Scripts](#configure-scripts)
   + [Pantheon Specific Scripts](#pantheon-specific-scripts)

## Upgrading

If you are using the standard scripts that ship with this package, upgrading
should be easier. With each version upgrade, you should check your
`.circleci/config.yml` file for changes against the `config.yml` file here.

The easiest way to do this is to use a standardized diff tool and diff
`.circleci/config.yml` with `config.yml`. An example may look like:
```
diff -u --color .circleci/config.yml ./vendor/fourkitchens/pots/config.yml
```

Validate the changes and move over the ones you want to keep.

## Dependencies

This package expects your project to have the following support scaffolding to
run out of the box:

- the composer scripts lint and code-sniff. Example:
  ```
   "scripts": {
      "lint": [
         "./node_modules/.bin/eslint ./",
         "find web/modules/custom web/themes/custom \\( -iname  '*.php' -o -iname '*.inc' -o -iname '*.module' -o -iname '*.install'-o -iname '*.theme' \\) '!' -path '*/node_modules/*' -print0 | xargs -0 -n1 -P8 php -l"
      ],
      "code-sniff": [
         "./vendor/bin/phpcs"
      ]
   }
  ```
- package.json with a build-theme script. Example:
   ```
      "scripts": {
         "theme-build": "cd ./docroot/themes/custom/sdsu && npm run build"
      }
   ```
- package.lock or shrinkwrap.
- preferably a .nvmrc
- .gitignore files with cut lines in them to distinguish source from artifact.
  Here's an example [.gitignore](https://github.com/pantheon-systems/example-drops-8-composer/blob/master/.gitignore).

Set up of the Circle tasks assumes you are doing this with a bot user. Please
ensure that the bot user you are using has account on both the GitHub
organization where your site lives and the hosting provider. You will
need:
 - the ability to log in as the bot user in GitHub and on the hosting provider
 - an SSH Key (private and public)
 - an api or machine token for the hosting tooling such as terminus or acli

## Installation

1. Install the package and copy over the template config.yml

    ```
    composer require fourkitchens/pots
    mkdir .circleci
    cp vendor/fourkitchens/pots/config.yml .circleci/config.yml
    ```
2. Make sure your composer.json and package.json meet the requirements of the
   default scripts.
3. Push the changes to a public GitHub branch.
4. Log in to https://app.circleci.com/
5. Navigate to the organization that your site's code lives under by clicking
   the icon in the top left corner where your name is and selecting the correct
   one.
6. Navigate to Projects
7. Find the Repo name for your site
8. Click the "Set Up Project" button next to it
9. Choose Fastest
10. Type in the branch you pushed your changes up to where the "git branch" icon
    is in the dialog.
11. Verify the wrench icon turns Green and lets you know it found a config.json
12. Click "Set Up Project"

The first pass will always fail. Move on to configuration.
## Configure Environment

There are some configuration steps that are shared between hosting environments.
Make sure to check out the settings specific to the environment you are pushing
to.

### Shared

#### Deploy Bot Setup
A Deploy Bot user will be needed. This tooling assumes Bender (the Four Kitchens
deploy bot) as the default, but does not provide any credentials you need to set
the tooling up. Ask a Web Chef about Bender, have the organization you are
working with create a new bot, or create the new bot for them using the steps
below. You will need to log in as this bot to do some of the configuration.

##### Create a GitHub Account for the Deploy Bot
1. Open a new browser instance or log out of your current GitHub instance.
2. Go to https://github.com/join.
3. Type a username, your email address, and a password. NOTE: Make sure the
   email address you enter goes to a real email account. If you use gmail, it is
   possible to have multiple "addresses" go to the same account using the `+` in
   your email. See how to [create task-specific email addresses](https://support.google.com/a/users/answer/9308648?hl=en)
4. Choose Sign up for GitHub, and then follow the instructions.
5. Securely provide the credentials to the client.
6. In a new browser instance, as an administrator of the organization that owns
   the site, [invite the bot user to the organization](https://docs.github.com/en/organizations/managing-membership-in-your-organization/inviting-users-to-join-your-organization#inviting-a-user-to-join-your-organization).

#### Configure an SSH Key
An SSH key is needed to be able to push commits from circleci to the hosting
provider's git repository. In some instances, the same ssh key is also needed
to be able to ssh into the hosting platform itself. Ask the client to generate
an ssh key pair or [generate](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#generating-a-new-ssh-key)
and securely provide the ssh key pair to the client.

1. Log in to https://app.circleci.com/
2. Navigate to the organization that your site's code lives under by clicking
   the icon in the top left corner where your name is and selecting the correct
   one.
3. Navigate to Projects
4. Find the Repo name for your site and click it.
5. Validate you see failed workflows.
6. Click on "Project Settings"
7. Click on "SSH Keys"
8. Navigate to "Additional SSH Keys"
9. Click "Add SSH Key"
10. Copy the contents of the private SSH Key you were provided (or generated)
    for the bot user into the Private Key field in the dialog that appears.
11. Verify that you have no extraneous spaces or newlines.
12. Click "Add SSH Key" to close the dialog and accept the changes.
13. Note the fingerprint for future use. **Note:** you can check to make sure
    the file was copied correctly by validating that the fingerprint in circleci
    is the same as what is displayed by the command
    `ssh-keygen -l -E md5 -f id_rsa` where idrsa is the filename of your key.

#### Get a Github Token
You must have a GitHub token so the Deploy Bot can post comments back to commits
or pull requests. This allows it to provide links and information about the
environments it created.

If you skipped here, make sure you follow steps 1-6 of "Configure an SSH Key" to
get to Circle's Project Settings"

1. In a new browser instance, log in to GitHub as the Deploy Bot.
2. Follow the instructions for [creating a personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token#creating-a-token)
3. Choose just repo:status, repo_deployment and public_repo for scopes
4. Save the access token securely, so you will have access to it. It will only
   be displayed once.

#### Configure Environment Variables

Here you will configure the common environment variables. Hosting specific
variables and steps will be provided farther down. The variables to configure
are as follows.

* `GITHUB_TOKEN` A GitHub access token so the bot user can comment back on the
  commit.
* `GIT_EMAIL` An arbitrary email that will be used as the committer when
  building the artifact.
* `CANONICAL_ENV` The environment to get canonical database and files from.

If you skipped here, make sure you follow steps 1-6 of "Configure an SSH Key" to
get to Circle's Project Settings"

1. Switch back to your browser instance where you are logged into CircleCI ->
   Project Settings
2. Click "Environment Variables" on the left hand side.
3. Click "Add Environment Variable"
4. Type "GITHUB_TOKEN" in the name
5. Copy the token value into "Value"
6. Click "Add Environment Variable" to accept the changes.
7. Click "Add Environment Variable"
8. Type "GIT_EMAIL" in the name
9. Type the email address associated with the Deploy Bot into "Value"
10. Click "Add Environment Variable" to accept the changes.

### Pantheon

* `SITE_NAME`: The Pantheon site id used to run terminus commands.
* `TERMINUS_TOKEN`: The Pantheon Machine Token used to operate terminus.

#### Create a Pantheon Account for your Deploy Bot

For Pantheon hosted sites, we need an account for our Deploy Bot so that our
deployments are linked to any one pantheon user.

1. Log in as an administrator of your Pantheon Organization.
2. Click your user's name in the top right corner of the dashboard
3. Navigate down to the organization name you want to create a user for.
4. Click the "People" tab.
5. Click the "Add User" button.
6. Select "Team Member" for Role.
7. Add the same email address you created the GitHub account for previously.
8. Click "Add User".
9. In a new browser instance, check the email that's associated with that user.
10. Accept the invitation.

#### Set up SSH Key
Your bot will need an ssh key configured to be able to push commits to Pantheon.
Use the public key of the pair generated in the "Configure an SSH Key" section.

Log out of your Pantheon account or use a separate browser instance to follow
the instructions from Pantheon to [Add Your SSH Key to Pantheon](https://pantheon.io/docs/ssh-keys#add-your-ssh-key-to-pantheon).
#### Get a Terminus Token (or Machine Token)

1. In the same browser instance as above, follow the instructions from Pantheon
to [Create a Machine Token](https://pantheon.io/docs/machine-tokens#create-a-machine-token)
2. Save the machine token securely, so you will have access to it. It will only
   be displayed once.

#### Configure More CircleCi Environment Variables
1. Navigate back to your CircleCI -> Project Settings -> Environment Variables
   browser instance.
2. Click "Add Environment Variable"
3. Type "SITE_NAME" in the name
4. Type the site id (or `TERMINUS SITE ID`) of your Pantheon site into "Value".
    **Note:** you can find the site id by looking at the site's dashboard in
    Pantheon. If you click the "Visit Site" button on any environment the url is
    in the format of
    `https://{{TERMINUS ENV}}-{{TERMINUS SITE}}.pantheonsite.io/`
5. Click "Add Environment Variable" to accept the changes.
6. Click "Add Environment Variable".
7. Type "TERMINUS_TOKEN" in the name.
8. Copy the machine token value you saved earlier into "Value".
9. Click "Add Environment Variable" to accept the changes.

### Acquia
* `SITE_NAME`: The acquia site id used to run Acquia Cloud API commands.
* `ACQUIA_REALM`: The Cloud API Realm. Usually "prod" or "devcloud".
* `ACQUIA_REPO`: The Acquia git repo.
#### Create an Acquia Account for your Deploy Bot

**TODO: FILL OUT THIS BIT**

#### Set up SSH Key

Your bot will need an ssh key configured to be able to push commits to Acquia.
Use the public key of the pair generated in the "Configure an SSH Key" section.

Log out of your Acquia account or use a separate browser instance to follow
the instructions from Acquia to [Add a public key to an Acquia profile](https://docs.acquia.com/cloud-platform/manage/ssh/enable/add-key/).

#### Configure More CircleCi Environment Variables
1. Navigate back to your CircleCI -> Project Settings -> Environment Variables
   browser instance.
2. Click "Add Environment Variable".
3. Type "ACQUIA_REPO" in the name.
4. Type the Acquia repo url into "Value".
   **TODO:** FLESH THIS OUT MORE WITH HELP ON HOW TO GET IT
5. Click "Add Environment Variable" to accept the changes.
6. Click "Add Environment Variable".
7. Type "ACQUIA_REALM" in the name.
8. Type the Acquia Realm id into "Value".
   **TODO:** FLESH THIS OUT MORE WITH HELP ON HOW TO GET IT
9. Click "Add Environment Variable" to accept the changes.
10. Click "Add Environment Variable".
11. Type "SITE_NAME" in the name.
12. Copy the Acquia site id into "Value".
    **TODO:** FLESH THIS OUT MORE WITH HELP ON HOW TO GET IT
13. Click "Add Environment Variable" to accept the changes.

## Configure CircleCI config.yml
There are many options you have, some shared, and some hosting specific.

### Pipeline Parameter Defaults

Currently, you can configure your entire script by setting up some pipeline
parameter defaults. These can be changed via API calls (advanced usage), but the
defaults will be used when you are making pull requests or commits directly to
the repository that houses your .circleci/config.yml.

In each one, change the value after the `default:` key. For example, to change
the docroot across the whole project, change:
```
  docroot:
    description: "Where composer installs drupal."
    default: "web"
    type: string
```
to
```
  docroot:
    description: "Where composer installs drupal."
    default: "docroot" #NOTE I CHANGED THIS
    type: string
```

The following parameters exist:
#### php-version
This is a string that represents the version number for PHP version to use
across the entire build.

If you are using Pantheon as a host-variant, this can only be a major.minor
version number such as `"8.1"` because Pantheon Docker containers only allow
the two digit version.

On other hosting platforms, you can use a three digit version number
(major.minor.patch), such as `"8.1.4"` if required, however 2 digits are
allowed.

#### tz
This is a string that represents the timezone. This may be important so that
jobs that do time calculations, print time stamps, or make commits are accurate.
See a [full list of timezone values](https://vdc-repo.vmware.com/vmwb-repository/dcr-public/3d076a12-29a2-4d17-9269-cb8150b5a37f/8b5969e2-1a66-4425-af17-feff6d6f705d/doc/timezone.html)
to find an appropriate one for you to use.

#### host-variant
This affects how the whole build behaves and what configurations are available
to you. The current options are "pantheon", "acquia", and "general". All our workflows
will provide you with "Artifact Build", committed the appropriate
repository. This allows you to use Git history to follow a build back to the source
commit we use in development.

##### pantheon
Pantheon provides you a workflow that builds multidev environments, options
around development branches, and a workflow to deploy code via approval through
the CircleCI user interface. The deploy process provided by this setting creates
an Artifact Build using Pantheon's [Terminus](https://github.com/pantheon-systems/terminus)
with the aid of the [Build Tools](https://github.com/pantheon-systems/terminus-build-tools-plugin)
plugin. These changes are committed only to the Pantheon git repository and not
to your "Source Repository", the one you create coding changes in.

##### acquia
Acquia provides you a very minimal workflow, however, it does provide
[acquia cli](https://github.com/acquia/cli) as part of the build. This allows
you to use supporting deploy methods like our [cloud hooks](https://github.com/fourkitchens/acquia-cloud-hooks)
to streamline the deployment process. For multidev capabilities, it is
recommended to use [tugboat](https://www.tugboatqa.com/). The deploy process
provided by these settings creates an Artifact Build using some standard git
commands. These changes are committed only to the Acquia git repository and not
to your "Source Repository", the one you create coding changes in.

##### general
General provides you with the barest of deployments, committing an artifact
build back to your source repository under a new branch that follows the naming
convention `deploy-{BRANCHNAME}`. Example, if your branch is named `test`, you
will have an artifact build committed to the `deploy-test` branch.

#### docroot
This setting should be set to the folder where your Drupal installation resides.
This should mirror the setting in `extra.drupal-scaffold.locations.web-root`.
This is typically either `web` for Pantheon and `docroot` for Acquia, but can
be any number of things like `public_html` for generic hosts.

#### artifact_workspace
This setting moves where the built artifact should be. This is particularly
helpful when you want to pick and choose items from the build versus just
sending the whole artifact to your host. The `~/project` directory is always
committed to an "Artifact Build". Therefore, by changing this directory to
something like `/tmp/project`, you can use rsync to move parts built by
the previous build script into `~/project`. By default, this value of this setting
is `~/project`, so that everything that was built during the "build" job is then
pushed to the host.

### Other Configuration

There are other configuration that cannot be affected by API calls and requires
you to modify your config.yml directly if you wish to change them temporally
or permanently.

#### persisting_dirs
There are the directories that you want to be copied in full from the build
portion of the workflow to the deploy portion of the workflow. You will
sometimes want to include other root directories that aren't included like
`node_modules`, `simplesaml`, or `private`. We exclude most top level
directories because they are unneeded on the hosting system itself.

## Configurable Environment Variables

Environment variables can be configured using the CircleCI Environment Variables
interface, or you can set them directly in `.circleci/config.yml`. Changing them
in the interface makes upgrading your `.circleci/config.yml` less problematic,
however, it hides some of the toggles you may be using. Per best practices,
make sure any secret is configured in the CircleCI UI. We also include all
mandatory environment variables in this way as well.

### Shared

* `GITHUB_TOKEN`: **Mandatory** A GitHub access token so the bot user can comment back on the
   commit or PR, and remove unneeded multidevs.
* `SITE_NAME`: The Pantheon or Acquia site id used to run terminus/acli
   commands. Defaults to the GitHub repo name.
* `GIT_EMAIL`: An arbitrary email that will be used as the committer when
   building the artifact. Defaults to `bender@fourkitchens.com`
* `CANONICAL_ENV`: Environment to get canonical database and files from
   Possible Values:
   * Acquia: dev, test, prod
   * Pantheon: dev, test, live

   Default: "prod" on Acquia. "live" on Pantheon
* `SANITIZE_SCRIPT`: Script used to sanitize databases. Only used when
   `CANONICAL_ENV` is not dev. There is no default.
* `SYNC_CONFIG`: The ability to turn configuration sync on or off. By default,
   Yes if Any directory in the ./config directory (inclusive) contains
   `system.site.yml`. Ex: YES if `./config/system.site.yml` or
   `./config/default/system.site.yml` or `./config/sync/system.site.yml`
   exists. Possible values are `YES`, or `NO`.

### Pantheon Specific

* `TERMINUS_TOKEN`: **Mandatory** The Pantheon machine token.
* `CI_BUILD`: Build CI multidevs on every commit on Pantheon. This way you get
   the ci-* environments. This may be useful for visual regression testing or
   workflows without PRs. Defaults to `NO`. Possible values are `YES` and `NO`.
* `MAIN_BRANCH`: Define the main branch releases are cut from. Defaults to
   `main` if the branch exists, `master` otherwise.
* `DEVELOPMENT_BRANCH`: Define the development branch where active development
   happens on GitHub. This branch is used most in gitflow development patterns.
   Defaults to `develop`.
* `REBUILD_MULTIDEV_ENV_EVERY_PUSH`: Re-sync content for multidevs every time a
   push is made to Pantheon. Defaults to `NO`. Possible values are `YES` and
   `NO`.
* `REBUILD_DEVELOPMENT_ENV_EVERY_PUSH`: Re-sync content for the GitHub
   development multidev on Pantheon every time a push is made to
   `DEVELOPMENT_BRANCH` branch. Defaults to `NO`. Possible values are `YES` and
   `NO`.
* `DEVELOPMENT_ENV`: Define the name of the multidev used for the GitHub
   development branch. Must follow the multidev naming conventions for Pantheon.
   Defaults to `github-dev`.

### Acquia Specific

* `ACQUIA_REPO`: **Mandatory** The address of the Acquia git repo. Example:
   `sitename@svn-21939.prod.hosting.acquia.com:sitename.git`.
* `ACQUIA_REALM`: **Mandatory** The Acquia Cloud API Realm.
   Usually "prod" or "devcloud".
   See [documentation](https://docs.acquia.com/acquia-cloud/api#realm). 
   Defaults to `prod`.

## Helper Environment Variables
These environment variables are unconfigurable. They are set to help you with
developing scripts on your own. Some contain the values of the pipeline
parameters previously mentioned.

* `HOST_VARIANT`: Contains the value provided by the host-variant pipeline
   parameter.
* `DATE_TIMEZONE`: Contains the value provided by the tz pipeline parameter.
* `DOCROOT`: Contains the value provided by the docroot pipeline parameter.
* `TERM`: "xterm"

## Configure Composer.json

There are 2 scripts that the default scripts require you to build so that it's
reusable across the project. You must be able to run the following commands in
your project.

```
composer run lint
composer run code-sniff
```
See the [Dependencies](https://github.com/fourkitchens/pots#dependencies) section for examples.

## Configure Scripts

Almost all actions provided by this framework are overloadable. By simply
providing a script in the correct location in `.circleci/scripts`, you can make
this tooling do what ever steps you want to. We provide a default set of actions
in the scripts section of this repository which you can use to base your custom
scripts off of.

The scripts available for overload are as follows:

- `test/static`: Provides static code testing such as linting and code standards
   validation. By default, this runs `composer run lint; composer run code-sniff`
- `build/php`: Provides functionality to build your application. By default,
   this is simply optimizing a production ready dependency install.
- `build/theme`: Provides functionality to build your custom themes. By default,
   this runs `npm run theme-build` and runs through `$DOCROOT/themes/custom` and
   performs a "cut" action on each .gitignore, so you can provide both a list of
   items that should be ignored while coding and a list that's ignored when
   building your artifact.
- `deploy`: All the actions needed to push the Artifact build to the remote
   hosting environment. On Pantheon, this includes creating and building the
   multidev. On Acquia and General hosting, this just gets the Artifact code
   to the repo it should live in.

### Pantheon Specific Scripts

- `drush-commands`: Provides the basic deployment drush commands to run update
   hooks, clear the cache, and sync configuration.
- `drush-config-import`: Provides the commands for importing configuration. By
   default, this provides drupal 8+ ready commands like `drush cim`, but can be
   swapped out for something like `drush fra` if on drupal 7 or have a features
   based site configuration setup.
- `post-drush-commands`: Some sites require changes to external systems, such
   as solr, third party cache, or want to run `drush deploy:hook` to allow drush
   to run `HOOK_deploy_NAME()` as some post deploy cleanup code. See
   [Drush docs](https://github.com/drush-ops/drush/blob/78aa3b9d6a77aa6feb73408ee772d76d88a59e89/drush.api.php).
- `deploy-to-test`: Provides the deployment logic to get changes to the
   staging environment. By default, this provides the "deploy" services, syncs
   live to test, and a standard deploy.
- `deploy-to-live`: Provides the deployment logic to get changes to the
   production environment. By default, this provides backup services, the
   "deploy" services as well as a standard deploy.
