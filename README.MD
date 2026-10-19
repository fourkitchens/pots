# Circle CI Starter for Projects

This Composer package provides the starts for what you need to test and deploy
a hosted site on something like Acquia, Pantheon, or elsewhere.

## What does POTS stand for?
Whatever you want it to stand for.  Here's some options:
* Push On To Site
* Party On That Site
* Perform On The Server
* People Overlook This Stuff
* ProjectCI Onward To Standardization

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
      - [run-playwright-e2e-tests](#run-playwright-e2e-tests)
      - [Visual regression tests (label-triggered)](#visual-regression-tests-label-triggered)
      - [playwright-vrt-target-env](#playwright-vrt-target-env)
      - [playwright-path](#playwright-path)
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
      - [Playwright Jobs](#playwright-jobs)
* [Configurable Environment Variables](#configurable-environment-variables)
   + [Shared](#shared-1)
   + [Pantheon Specific](#pantheon-specific)
   + [Acquia Specific](#acquia-specific)
* [Helper Environment Variables](#helper-environment-variables)
* [Configure Composer.json](#configure-composerjson)
* [Configure Scripts](#configure-scripts)
   + [Pantheon Specific Scripts](#pantheon-specific-scripts)
* [Automatic Security Updates](#automatic-security-updates)
* [Automated minor composer updates](#automated-minor-composer-updates)
   + [Steps to set the keys](#steps-to-set-the-keys)
   + [Steps to set the ClickUp integration (optional)](#steps-to-set-the-clickup-integration-optional)
   + [Steps to set the Productive.io integration (optional)](#steps-to-set-the-productiveio-integration-optional)
   + [Steps to set the AI key (optional)](#steps-to-set-the-ai-key-optional)
   + [Database updates and configuration export](#database-updates-and-configuration-export)

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

### Migrating off the `build-tools-ci` image

Pantheon deprecated the `quay.io/pantheon-public/build-tools-ci` Docker image family
in June 2026. If your `.circleci/config.yml` still pins that image on any Pantheon job
(`deploy_to_pantheon*`, `security_updates_check`) or the Playwright jobs, replace those
`docker.image` entries with `cimg/php:<< pipeline.parameters.php-version >>` (Playwright
jobs use the `playwright-executor`) and add the `install-terminus` step to each job that
uses Terminus, exactly as shipped in the current `config.yml`. Terminus is now installed
at runtime and pinned via the new `terminus-version` and `terminus-build-tools-version`
parameters — set those if you need versions other than the defaults.

### BREAKING: the update scripts moved and were renamed

This release turns AutoSec into two flows (security, and routine minor composer updates)
that share one job and one directory. Three things move. Do them in one pass.

**1. The scripts directory.** `scripts/security-updates/` is now `scripts/updates/`, and the
entry script `automatic-update` is now `run-update`, which takes a mode. If your project has
overrides, move them:

```bash
git mv .circleci/scripts/security-updates .circleci/scripts/updates
# if you overrode the entry script:
git mv .circleci/scripts/updates/automatic-update .circleci/scripts/updates/run-update
# templates are now per-mode:
#   PULL_REQUEST_TEMPLATE.md -> PULL_REQUEST_TEMPLATE-security.md
#   TICKET_TEMPLATE.md       -> TICKET_TEMPLATE-security.md
```

**2. The environment variables**, which are shared by both flows and so lost their `SEC_`
prefix. Rename any you have set in CircleCI:

| old | new |
| --- | --- |
| `SEC_UPDATE_RUN_DB_UPDATES` | `UPDATE_RUN_DB_UPDATES` |
| `SEC_UPDATE_DB_ENV` | `UPDATE_DB_ENV` |
| `SEC_UPDATE_DB_DUMP` | `UPDATE_DB_DUMP` |
| `SEC_UPDATE_CREATE_BACKUP` | `UPDATE_CREATE_BACKUP` |
| `SEC_UPDATE_BASELINE_COMMIT` | `UPDATE_BASELINE_COMMIT` |

**3. The trigger parameter** — see immediately below.

### BREAKING: `click-data` is now `update-data`

AutoSec's ticketing configuration used one pipeline parameter per provider. That is now a
single `update-data` blob, with the provider chosen by its `ticketing_system` key.
**`click-data` no longer exists.**

This one needs care, because CircleCI **fails any pipeline that receives a parameter the
config does not declare**:

```
• Unexpected argument(s): click-data
error: Config file "config.yml" contains compilation errors.
```

So for each project, the trigger POST and the `config.yml` merge have to land **together**.
If you merge the config and leave the trigger alone, the next security run fails — and it
fails at trigger time, nowhere near the change that caused it.

Rename the parameter in your Evercurrent (or CircleCI triggers UI) POST body:

```diff
 {
   "parameters": {
     "run-sec-updates-check": true,
-    "click-data": "{\"list_id\":\"901...\",\"client_id\":\"<uuid>\"}"
+    "update-data": "{\"ticketing_system\":\"clickup\",\"list_id\":\"901...\",\"client_id\":\"<uuid>\"}"
   }
 }
```

The ClickUp keys inside the blob are unchanged and `CU_TOKEN` stays exactly as it is, but
a project staying on ClickUp now has to say so: add `"ticketing_system":"clickup"` to the
blob, or set the `TICKETING_SYSTEM` env var. The default is **`productive`**, so a blob
that says nothing will try Productive, find no `PRODUCTIVE_TOKEN`, and create no ticket —
the run logs a warning and the PR carries a note, but the PR itself still succeeds. Moving a project to Productive is then a separate,
independent step — see
[Steps to set the Productive.io integration](#steps-to-set-the-productiveio-integration-optional).

### Enabling the AutoSec database phase

AutoSec now runs the database updates a security release ships and commits the
configuration they change. The scripts come with the package, but the job needs a database
sidecar, so hand-merge this into your `.circleci/config.yml`:

```diff
 parameters:
+  mariadb-version:
+    description: >
+      cimg/mariadb tag for the database sidecar the AutoSec job uses to run Drupal's
+      database updates. Match your production database version where you can.
+    type: string
+    default: "10.11"
   terminus-version:

 jobs:
   security_updates_check:
     <<: *defaults
+    resource_class: medium
     docker:
       - image: cimg/php:<< pipeline.parameters.php-version >>
+      - image: cimg/mariadb:<< pipeline.parameters.mariadb-version >>
     ...
     steps:
       ...
       - add_ssh_keys
+      - run:
+          name: Install the MariaDB client
+          command: sudo apt-get update && sudo apt-get install -y mariadb-client
       - run: composer audit --format=json > /tmp/projects_to_update.json 2>/dev/null || true
       - run:
           name: Check security updates
+          no_output_timeout: 30m
           command: |
```

Then check the requirements in
[Database updates and configuration export](#database-updates-and-configuration-export) —
in particular that `drush/drush` is in `require` and that your `settings.php` includes
`settings.local.php`. If you would rather keep AutoSec's previous composer-only behaviour,
merge the diff anyway and set `UPDATE_RUN_DB_UPDATES=NO`.

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
3. Choose the complete repo access option.
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
14. Click "Add Environment Variable".
15. Type "CU_TOKEN" in the name.
16. Paste your ClickUp API token into "Value" (stored in 1Password). This is the only
    ClickUp secret; the rest of the settings travel in the `update-data` pipeline
    parameter — see [Automatic Security Updates](#automatic-security-updates) below.
17. Click "Add Environment Variable" to accept the changes.

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
#### run-sec-updates-check
This boolean triggers the [AutoSec](#automatic-security-updates) process. It is `false`
by default and is not meant to be flipped in the file: an external scheduler (Evercurrent,
or the CircleCI triggers UI) POSTs it as `true` to start a security-update run. When it is
`true` the normal build/deploy workflow is skipped and only `security_updates_check` runs,
and only on `main`/`master`.

#### run-composer-updates-check
This boolean triggers the routine composer-update process — **minor and patch updates only,
never a major**. Like `run-sec-updates-check` it defaults to `false` and is meant to be POSTed
by an external scheduler. If both flags are set on one pipeline the security run wins, so two
update branches can never race. See
[Automated minor composer updates](#automated-minor-composer-updates).

#### update-data
A JSON blob of the non-secret ticketing settings for the AutoSec ticket, sent by the same
external POST that sets `run-sec-updates-check`. Defaults to `"{}"`, which disables
ticketing.

Which keys matter depends on `ticketing_system`, because only one ticketing system is
ever active for a run:

| key                  | used by    | required | value                                                       |
| -------------------- | ---------- | -------- | ----------------------------------------------------------- |
| `ticketing_system`   | any        | no       | `clickup`, `productive` or `none`. Falls back to the `TICKETING_SYSTEM` env var, then to `productive` |
| `list_id`            | clickup    | yes      | ClickUp list the task is created in                          |
| `client_id`          | clickup    | yes      | value for the "Client" custom field (a drop-down option UUID)|
| `status`             | both       | no       | status **name** the ticket opens in; defaults to `Ready for Dev` |
| `organization_id`    | productive | yes      | Productive organization id (`X-Organization-Id`)             |
| `project_id`         | productive | yes      | the project (workspace) the task is created in               |
| `task_list_id`       | productive | no       | task list / milestone to file the task under                 |
| `board_id`           | productive | no       | board (folder) to file the task under                        |
| `workflow_status_id` | productive | no       | workflow status id; overrides `status` and skips the name lookup |
| `task_url_template`  | productive | no       | override the link built for the PR body                      |
| `assignee_id`        | both       | no       | user/person id to assign                                     |

The API token is deliberately *not* in here — pipeline parameters are readable through the
CircleCI API and UI, so the token is the `CU_TOKEN` or `PRODUCTIVE_TOKEN` env var instead.

#### mariadb-version
A string naming the `cimg/mariadb` tag used for the database sidecar that the AutoSec job
runs Drupal's database updates against. Defaults to `"10.11"`. Match your production
database version where you can. This container is only used by `security_updates_check`;
it has nothing to do with your deployed environments.

#### run-playwright-e2e-tests
This boolean controls whether the Playwright end-to-end test job runs after the
Pantheon multidev is created.

Default: `true`

When enabled, the `playwright-e2e-test` job will:

- restore the built project from the artifact workspace
- install dependencies from the Playwright test directory
- install Playwright browsers
- wake the Pantheon environment
- run `npx playwright test --grep-invert "@vrt"`

Use this when you want standard browser coverage on the deployed multidev but
you do not want visual regression tests mixed into that run.

#### Visual regression tests (label-triggered)

VRT is no longer controlled by a parameter or a manual approval. It runs when a
pull request is labeled — **`run vrt tests`** (VRT only) or **`run vrt tests with
fresh db`** (refresh DB + files from live, then VRT). See
[Visual regression testing](#visual-regression-testing) below for the trigger
prerequisites and behavior.

#### playwright-vrt-target-env
This string defines which Pantheon environment should be used as the visual
baseline for VRT comparisons.

Default: `"live"`

During the `playwright-vrt-test` job, this value is exported as
`VRT_TARGET_ENV`. The currently deployed multidev becomes the source
environment, and the target environment becomes the baseline for comparison.

#### playwright-path
This string points to the directory that contains your Playwright project.

Default: `"test/playwright"`

This directory is expected to contain the files needed for Playwright CI runs,
including `package.json` and your Playwright configuration. The current jobs
use this path for:

- `npm ci`
- `npx playwright install --with-deps`
- `npx playwright test --grep-invert "@vrt"`
- `npm run vrt:ci`

If your tests live somewhere else, update this parameter instead of changing
each job manually.

#### php-version
This is a string that represents the version number for PHP version to use
across the entire build.

This value must be a valid `cimg/php` tag. Both major.minor (e.g. `"8.4"`)
and major.minor.patch (e.g. `"8.4.2"`) are supported.

#### terminus-version
This is a string controlling the [Terminus](https://github.com/pantheon-systems/terminus)
version installed at runtime by the `install-terminus` command. Because Pantheon jobs
now run on a standard image instead of the deprecated `build-tools-ci` container,
Terminus is installed during the build rather than baked into the image.

Provide a full Terminus version to pin (e.g. `"4.3.2"`, the default). Pinning keeps
builds reproducible and prevents a bad upstream release from breaking every project at
once. The Build Tools and Secrets plugins are installed at their latest versions
compatible with the installed Terminus, so there is no separate version parameter for
them.

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

Pantheon jobs run on the standard `cimg/php` image and install Terminus (and, for the
dev/multidev deploy, the Build Tools plugin) at runtime via the `install-terminus`
command. This replaces the deprecated `quay.io/pantheon-public/build-tools-ci`
container, which [Pantheon stopped maintaining in June 2026](https://docs.pantheon.io/release-notes/2026/06/build-tools-ci-deprecated).
The Build Tools plugin itself is not deprecated and is still used. The Terminus version
is controlled by the `terminus-version` parameter described above; its plugins install
at their latest compatible versions.

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

#### Playwright Jobs
The Playwright jobs are currently part of the Pantheon workflow only. Their
purpose is to validate the freshly deployed multidev before any later manual
deployment steps.

The workflow order is:

- `deploy_to_pantheon` deploys the multidev
- `playwright-e2e-test` runs automatically after that deploy (when
  `run-playwright-e2e-tests` is enabled)

VRT runs in a separate, label-triggered workflow (see below), not inside
`build-deploy-pantheon`.

Some practical details:

- The E2E job excludes any test tagged with `@vrt`
- The VRT job expects an `npm run vrt:ci` script in your Playwright project
- Both jobs store the Playwright HTML report as a CircleCI artifact

### Visual regression testing

VRT is triggered on demand by labeling a pull request. There are two labels:

- **`run vrt tests`** → the `vrt-on-label` workflow runs VRT against the PR's
  already-deployed multidev (the one `build-deploy-pantheon` created on push). It
  does not redeploy; the `build` job only produces the workspace and dependencies
  the VRT jobs need.
- **`run vrt tests with fresh db`** → the `vrt-on-label-fresh-db` workflow first
  runs `vrt_sync_from_live`, which clones the **database and files** from the
  canonical/live environment into the multidev and runs the deploy commands
  (`drush-commands`, including `deploy:hook`), then runs VRT. Use this when the
  visual diff should reflect the branch's code applied on top of live content.
  (The sync refuses to run against `dev`/`test`/`live` as a safety guard.)

Under the hood, each VRT workflow is gated on the `vrt-mode` pipeline parameter
(`plain` / `fresh-db`); a normal push/PR pipeline leaves it at the default `none`
and runs the usual `build-deploy-pantheon` workflow only. CircleCI's native label
triggers can't match arbitrary label names, so the labels are wired up through a
small GitHub Actions workflow that calls the CircleCI API.

**Prerequisite — one-time project setup:**

1. **Copy the trigger workflow** `templates/github-workflows/vrt-label-trigger.yml`
   from this package into your repository's `.github/workflows/` directory.
2. **Add a CircleCI API token** as the repository Actions secret **`CIRCLECI_TOKEN`**
   (a machine/bot user's personal API token is recommended). The Action uses it to
   trigger the pipeline via `POST /api/v2/project/gh/<org>/<repo>/pipeline`.
3. **Create the two labels** on the repo: `run vrt tests` and
   `run vrt tests with fresh db`.

When you label a PR, the Action maps the label to `vrt-mode` (`plain` or
`fresh-db`) and starts a CircleCI pipeline on the PR's head branch. Only the
matching VRT workflow runs — it does not start another `build-deploy-pantheon`.
(Fork PRs are not supported: GitHub withholds secrets from forked-PR Action runs
and the head branch isn't in the base repo.)

To run VRT: push your branch (the normal pipeline builds and deploys the
`pr-<n>` multidev), then add either label to the PR. Remove and re-add the label
to run it again. Use `playwright-vrt-target-env` to choose the baseline
environment for the comparison.

> Note: `drush deploy:hook` now runs as part of the standard deploy commands
> (`scripts/pantheon/drush-commands`) on every Pantheon deploy, not just VRT.

This makes the default flow easier to manage: regular browser coverage can run
automatically, while the slower visual comparison step stays opt-in.

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
* `BASIC_USER`: Optional username used when the deployed Pantheon environment is
   protected by HTTP basic authentication. If set together with `BASIC_PASS`,
   the Playwright E2E job will use those credentials when waking the site over
   HTTP.
* `BASIC_PASS`: Optional password paired with `BASIC_USER` for HTTP basic
   authentication during Playwright E2E runs.

### AutoSec Specific

All optional — every one of these has a working default. See
[Automatic Security Updates](#automatic-security-updates) for the full flow.

* `CU_TOKEN`: ClickUp API token used to open a ticket for each security-update PR. When
   unset, AutoSec still updates packages and opens the PR, just without a ticket.
* `PRODUCTIVE_TOKEN`: Productive.io API token, the equivalent of `CU_TOKEN`. Unset means
   no Productive ticket, and nothing else changes.
* `UPDATE_LEVEL`: How far the routine composer update is allowed to go — `minor` (the
   default: minor and patch releases) or `patch` (patch releases only). There is
   deliberately no `major`: a major version is breaking by definition and is never applied
   automatically.
* `UPDATE_EXCLUDE`: Space-separated globs of packages to hold back from the routine update,
   e.g. `"drupal/core-* symfony/*"`. Lets a project skip a package without editing its
   version constraints.
* `TICKETING_SYSTEM`: Fallback for which ticketing system AutoSec opens a ticket in. One
   of `clickup`, `productive`, or `none`. The trigger POST decides this now, through the
   `ticketing_system` key in `update-data`; this env var is only consulted when that key
   is absent, and when neither says anything the default is **`productive`**. Set it for a
   project whose trigger you do not control. An unrecognised value logs a warning and skips
   ticketing; it never fails the PR.
* `OPENAI_API_KEY`: Key for an OpenAI-compatible API used to generate functional testing
   steps. When unset, the AI step is skipped entirely and the PR is created without it.
* `OPENAI_API_BASE`: Root of the OpenAI-compatible API. Defaults to
   `https://api.openai.com/v1`. Point it at any compatible provider, including free ones.
* `OPENAI_MODEL`: Model id. Defaults to `gpt-4o-mini`.
* `OPENAI_TIMEOUT`: Per-request timeout in seconds. Defaults to `45`.
* `UPDATE_RUN_DB_UPDATES`: Set to `NO` to skip the database updates and configuration
   export, leaving AutoSec with its composer-only behaviour. Defaults to `YES`.
* `UPDATE_DB_ENV`: Environment to pull the AutoSec database from. Defaults to
   `CANONICAL_ENV`, else `live`.
* `UPDATE_CREATE_BACKUP`: Set to `YES` to create a fresh Pantheon backup before
   downloading instead of using the most recent one. Defaults to `NO`.
* `UPDATE_DB_DUMP`: Path to a local gzipped dump. When set, Terminus is skipped and
   this file is imported instead. Intended for running the AutoSec scripts by hand.
* `UPDATE_BASELINE_COMMIT`: What to do when a plain configuration export of the
   *unmodified* site already differs from `./config`. `YES` (default) commits that
   pre-existing drift as its own commit so the per-package commits stay attributable; `NO`
   discards it; `ABORT` skips the configuration export altogether.
* `CI_SETTINGS_FILE`: Settings file AutoSec writes the CI database credentials into,
   relative to the project root. Must be a file your `settings.php` already includes.
   Defaults to `$DOCROOT/sites/default/settings.local.php`.

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

For Playwright support, your project should also provide a Playwright workspace
at the path configured by `playwright-path`. In practice that means:

- a `package.json` that supports `npm ci`
- standard E2E tests that can run with `npx playwright test --grep-invert "@vrt"`
- a VRT script named `vrt:ci` for the visual regression job

If you want a spec to run only as part of VRT, tag it with `@vrt` so it is
excluded from the standard E2E job.

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

## Automatic Security Updates.

POTS contains steps and scripts to automatically look for security updates and install them into the different contributed projects.

This was build making use of CircleCI PipeLine parameters to trigger the CI job that run that scripts that checks and gets the secutity updates.

To make it trigger recluntly we have a couple of options:

- Evercurrent (Recommended)
- CircleCi triggers interface


To make the Automatic security updates works for our project, we will require to follow the next steps:

- Create a new set of SSH keys to be able to push the changes back to github (github deploy key)
- (Optional) Configure the ClickUp and/or Productive.io integration, so a ticket is created for each security-update PR
- (Optional) Configure the AI integration (OpenAI, or any compatible provider)
- (Optional) Review the [database updates and configuration export](#database-updates-and-configuration-export), which is on by default

### Steps to set the keys
When continuous integration is configured on a project, CircleCI generates a set of SSH keys and automatically adds the private key to CircleCI and the public key to GitHub. This way CircleCI will have access to the repository in GitHub, but this access is just read-only. Originally for POTS this access is enough since it only needs reading the repository on GitHub and writing on the platform where the website is hosted (Acquia, Pantheon, Platform, etc).

With the arrival of AutoSec to POTS, this set of SSH keys is no longer enough, because AutoSec requires reading the repository, executing the security updates, and sending the changes to GitHub, therefore starting with AutoSec it is necessary to have read/write keys. CircleCI cannot generate keys with write access, therefore it is necessary to externally create a set of SSH keys and manually add them to both CircleCI and GitHub.

1. The keys must be generated, either with a command in the console through [this guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) or they can also be generated through [1password](https://developer.1password.com/docs/ssh/manage-keys/).
2. Add the private key to CircleCI: ` Project Settings -> SSH keys -> Additional SSH Keys `.
3. Add the public key to GitHub: ` Project Settings -> Deploy Keys `.

### Steps to set the ClickUp integration (optional)

When configured, AutoSec creates a ClickUp task for each update PR and links it in the PR
body as `ClickUp CU-<id>` (or the task's custom id). Ticketing is handled by
`scripts/updates/create-clickup-ticket` and is entirely optional — if it is not
configured, AutoSec still updates packages and opens the PR, just without a ticket.

ClickUp is the default, so there is nothing to select. The API token is a CircleCI secret;
the rest of the settings travel in the `update-data` pipeline parameter (a JSON blob)
so they can be set per-trigger without touching config:

1. **Token** — add a CircleCI project env var `CU_TOKEN` with your ClickUp API token
   (`Project Settings -> Environment Variables`). Kept out of `update-data` because
   pipeline parameters are readable via the CircleCI API/UI.
2. **`ticketing_system`** — set it to `clickup` in the `update-data` blob. This is no
   longer optional: the default is now `productive`, so a ClickUp project that says
   nothing gets no ticket.
3. **`update-data`** — the external trigger POST that sets `run-sec-updates-check` also
   sends `update-data`, a JSON object with these keys:

   | key           | required | value                                                            |
   | ------------- | -------- | ---------------------------------------------------------------- |
   | `list_id`     | yes      | ClickUp list the task is created in                              |
   | `client_id`   | yes      | value for the "Client" custom field (a **drop-down option UUID**) |
   | `status`      | no       | a status **name** on the list; defaults to `Ready for Dev`       |
   | `assignee_id` | no       | ClickUp user id to assign                                        |

   Example: `{"list_id":"901327866278","client_id":"<option-uuid>","status":"in progress"}`

#### Finding the ids (with `CU_TOKEN` set)

```bash
# list_id — also visible in the list URL: .../v/li/<list_id>
curl -s -H "Authorization: $CU_TOKEN" \
  https://api.clickup.com/api/v2/team/<workspace_id>/space | jq '.spaces[] | {id, name}'
curl -s -H "Authorization: $CU_TOKEN" \
  https://api.clickup.com/api/v2/space/<space_id>/list | jq '.lists[] | {id, name}'

# client_id — the "Client" custom field is a drop-down; use an option's UUID (.id), not a name.
curl -s -H "Authorization: $CU_TOKEN" \
  https://api.clickup.com/api/v2/list/<list_id>/field \
  | jq '.fields[] | select(.name=="Client") | {type, options: .type_config.options}'

# status — use the status NAME (not id/uuid), any case. Defaults to "Ready for Dev".
curl -s -H "Authorization: $CU_TOKEN" \
  https://api.clickup.com/api/v2/list/<list_id> | jq -r '.statuses[].status'
```

The status is checked against the list before the task is created. A name the list does
not define is logged as a warning and the task opens in the list's default status instead
of failing. If a create returns HTTP 400, check the `ECODE`: `FIELD_011` = the `client_id`
isn't a valid drop-down option.

### Steps to set the Productive.io integration (optional)

Four Kitchens is moving from ClickUp to Productive, so AutoSec ships both and switching is
a configuration change rather than a code change.

**Migrating a project** is one key in the trigger POST: set `ticketing_system` to
`productive` inside `update-data`. The other keys in the blob change with it, since the two
systems read different ones out of it.

| `ticketing_system` | Result |
| --- | --- |
| `clickup`            | ClickUp ticket |
| `productive`, or absent with no `TICKETING_SYSTEM` set | Productive task |
| `none`               | no ticket; the PR is still created |
| anything else        | warning logged, ticketing skipped; the PR is still created |

Resolution order is `ticketing_system` in `update-data`, then the `TICKETING_SYSTEM` env
var, then `productive`. Migration is per trigger and reversible: change the key back and
the next run uses ClickUp again.

**Setup.** Exactly like ClickUp: the API token is a CircleCI secret, everything else travels
in `update-data` so it can be set per-trigger.

1. **Token** — add a CircleCI project env var `PRODUCTIVE_TOKEN`
   (`Project Settings -> Environment Variables`). Kept out of `update-data` because
   pipeline parameters are readable via the CircleCI API/UI.
2. **`ticketing_system`** — set it to `productive` in the `update-data` blob, or leave
   it out: `productive` is the default.
3. **`update-data`** — the external trigger POST that sets `run-sec-updates-check` also
   sends `update-data`. Productive reads these keys from it:

   | key                  | required | value                                                    |
   | -------------------- | -------- | -------------------------------------------------------- |
   | `organization_id`    | yes      | Your Productive organization id, sent as `X-Organization-Id` |
   | `project_id`         | yes      | The project (workspace) the task is created in           |
   | `task_list_id`       | no       | Task list / milestone to file the task under             |
   | `board_id`           | no       | Board (folder) to file the task under                    |
   | `assignee_id`        | no       | Person id to assign                                      |
   | `status`             | no       | Workflow status **name** to open the task in; defaults to `Ready for Dev` |
   | `workflow_status_id` | no       | Workflow status id; overrides `status` and skips the lookup |
   | `task_url_template`  | no       | Override the link built for the PR body (see below)      |

   Example: `{"organization_id":"31","project_id":"123456","task_list_id":"789"}`

   Optional relationships are omitted from the request entirely when unset — Productive
   rejects a relationship sent as null.

   The status name is looked up, ignoring case and spacing, among the statuses the project
   uses. If there is no status by that name, a warning is logged with the names the project
   does have, and the task opens in Productive's default status (usually Backlog). After the
   task is created, its status is checked and corrected with an update if it did not take.

   The task is due a week after it is created.

   Productive subscribes whoever creates a task, which for AutoSec is the owner of
   `PRODUCTIVE_TOKEN`. That person is taken off the task's subscribers right after it is
   created, unless they are also its assignee. If Productive does not return the task's
   subscriber list, only the assignee (or nobody) is left subscribed.

   The PR body links the task by its number (`Productive #123`).

#### Finding the ids (with `PRODUCTIVE_TOKEN` set)

`organization_id` is the number directly after `app.productive.io` in your browser's
address bar. For the rest:

```bash
AUTH=(-H "X-Auth-Token: $PRODUCTIVE_TOKEN" -H "X-Organization-Id: <organization_id>")

# project_id
curl -s "${AUTH[@]}" "https://api.productive.io/api/v2/projects" \
  | jq '.data[] | {id, name: .attributes.name}'

# task_list_id (scoped to the project)
curl -s "${AUTH[@]}" "https://api.productive.io/api/v2/task_lists?filter[project_id]=<project_id>" \
  | jq '.data[] | {id, name: .attributes.name}'

# assignee_id
curl -s "${AUTH[@]}" "https://api.productive.io/api/v2/people" \
  | jq '.data[] | {id, name: .attributes.name}'
```

#### Ticket body formatting

Both providers build the same body from `TICKET_TEMPLATE-<mode>.md`. The updated projects
are a bullet list, and each package that could not be updated is a bullet with composer's
explanation under it as a code block. ClickUp gets the body as Markdown
(`markdown_content`). Productive gets it as HTML, with an empty paragraph wherever the
template has a blank line, because Productive puts no space between paragraphs. Keep
`[PROJECTS]` on a line of its own in an overridden template to get the list. Left inline,
it gets the old comma-separated form.

The title, the body and the default status live in `scripts/updates/ticket-lib.sh`, which
both provider scripts source. It follows the usual override pattern at
`.circleci/scripts/updates/ticket-lib.sh`. An overridden `create-<provider>-ticket` should
print one line, `<reference><TAB><url>`. A bare URL still works, but then the PR body shows
the raw URL instead of the ticket reference.

#### A caveat on the ticket link

Productive's API returns the created task's `id`, but not a web URL for it, and the
permalink shape is not part of the documented API. POTS therefore builds the link from a
template, defaulting to `https://app.productive.io/{org}/task/{id}`. If your Productive
tasks live at a different path, set `task_url_template` in `update-data` — `{org}` and
`{id}` are substituted. Only the link in the PR body is affected; the task itself is
created either way.

### Steps to set the AI key (optional)

AutoSec can use AI to generate functional testing steps for the packages it updates automatically. These steps are added to the PR body, giving the developer performing the tests useful guidance.

The integration is **entirely optional and cannot break a run**. `run-update` checks
whether `OPENAI_API_KEY` is set and skips the request when it isn't, and every failure mode
— no key, wrong key, unreachable endpoint, rate limit, timeout — is non-fatal: the request
is abandoned, the reason is logged, and the security PR is created without the AI section.
Requests are also capped by `OPENAI_TIMEOUT` (45s), so a hanging provider cannot stall the
job.

1. Generate an API key with your chosen provider (see the table below).
2. Add it to CircleCI: `Project Settings -> Environment Variables -> Add Environment Variable`.
3. Name it `OPENAI_API_KEY` and paste the value.
4. Unless you are using OpenAI itself, add `OPENAI_API_BASE` and `OPENAI_MODEL` too.

#### Using a free provider

**There is no free tier of OpenAI's own API.** What *is* free is a number of providers that
speak the same Chat Completions protocol, so POTS reaches them with no code difference —
only the base URL, the model and the key change:

| Provider | `OPENAI_API_BASE` | `OPENAI_MODEL` | Free limits |
| --- | --- | --- | --- |
| OpenAI (default) | `https://api.openai.com/v1` | `gpt-4o-mini` | none — paid per request |
| **Groq** (recommended) | `https://api.groq.com/openai/v1` | `llama-3.3-70b-versatile` | 30 req/min, 1000 req/day, no credit card |
| OpenRouter | `https://openrouter.ai/api/v1` | `meta-llama/llama-3.3-70b-instruct:free` | 20 req/min, 50 req/day |
| Cerebras | Cerebras OpenAI-compatible endpoint | `llama-3.3-70b` | 30 req/min, no credit card |
| Google Gemini | Gemini OpenAI-compatible endpoint | `gemini-2.0-flash` | 5–15 req/min |

Groq is the recommendation for AutoSec: a run makes one request per updated package, so a
handful per run — far inside 1000/day, and no card is required to sign up.

Two things to weigh before pointing this at a free provider. Google states that prompts on
the free Gemini tier may be used to improve its models outside the EU, UK and EEA. And the
prompt contains the package names, the update hooks that ran and the configuration files
that changed — no credentials or site content, but it does describe your site's stack, so
check that this is acceptable for the project before enabling it.


### Database updates and configuration export

A security release often ships a `hook_update_N` or `hook_post_update_NAME` that rewrites
configuration. Left alone, AutoSec would open a PR containing only the `composer.json` /
`composer.lock` change, and the configuration half of the update would surface later, by
hand, on somebody's local.

So `security_updates_check` stands up a real, throwaway Drupal site inside the job: it
restores your canonical database into a `cimg/mariadb` sidecar, runs the database updates
each package brings with it, exports the configuration, and commits the result to the same
AutoSec branch. This is on by default; set `UPDATE_RUN_DB_UPDATES=NO` to turn it off.

#### What the job actually does

1. `scripts/updates/setup-drupal-env` runs **once**, and only after AutoSec has
   confirmed there is something to update — a run with no advisories never pays for a
   database restore.
   1. Resolves drush at `./vendor/bin/drush` and refuses to continue if it isn't there.
   2. Waits for the database sidecar to accept connections.
   3. Writes the CI database credentials to `CI_SETTINGS_FILE`.
   4. Downloads the database with `terminus backup:get` and imports it. If `SANITIZE_SCRIPT`
      is set, it is run against the restored database.
   5. Confirms Drupal connects, then asks Drupal where its configuration sync directory is
      and **aborts unless that directory really holds this site's configuration**.
   6. `drush updatedb` to drain updates already pending on the canonical environment, then
      `drush config:import` so the active configuration matches what is in git, then a
      baseline `drush config:export`.
2. Then, for **each** updated package, `scripts/updates/apply-db-updates` runs
   `drush updatedb`, `drush config:export`, and commits any changed configuration as
   `(AUTO-SEC): Exported configuration for <package>`.

The result is one `composer.*` commit and (where there was anything to export) one
configuration commit per package, so a reviewer can see exactly which module caused which
configuration change.

#### Why the `config:import` in step 1.6 matters

It is the step that makes the diffs readable. A live database's configuration has almost
always drifted from what is in `./config`. Export straight from a restored live database
and that drift lands in the PR alongside the module's changes, burying them. Importing
`./config` first means the only thing a later export can produce is what the update hooks
actually changed.

If the site's configuration is already drifted in a way a plain export reveals, that shows
up as a separate `(AUTO-SEC): Baseline config export before security updates` commit, kept
apart from the per-package commits. `UPDATE_BASELINE_COMMIT` controls this.

#### Requirements

* **`TERMINUS_TOKEN`**, already mandatory for Pantheon deploys, is used to pull the database.
* **`drush/drush` must be in `require`, not `require-dev`** — CI installs with `--no-dev`.
* **Your `settings.php` must include `settings.local.php` when it exists**, which is the
  Pantheon scaffold's default and is what both of our reference projects do:
  ```php
  if (file_exists(__DIR__ . '/settings.local.php')) {
    include __DIR__ . '/settings.local.php';
  }
  ```
  If your project uses a different filename, point `CI_SETTINGS_FILE` at it. The file is
  written at build time and never committed.
* **`$settings['config_sync_directory']` must point at your real exported configuration**
  in CI. This is the single most common way to get this wrong: a `config_sync_directory`
  computed from an environment variable can resolve to an empty directory under CI, and an
  export there would write your entire site configuration to the wrong place. AutoSec
  checks for `system.site.yml` in whatever directory Drupal reports and refuses to export
  if it isn't there.

#### When something goes wrong

Every failure in this phase is contained: it disables the database phase for the rest of
the run, records the reason, and lets AutoSec finish the composer updates, the push and the
PR. The reason is written into the PR body under "Database updates and configuration
changes", prefixed with :warning:, so the reviewer knows the configuration still has to be
exported by hand. Nothing here can prevent a security update from reaching a PR.

Failures handled this way include: drush missing, no mysql client, the database never
coming up, `settings.php` not picking up the CI settings file, a config sync directory that
isn't the site's configuration, `config:import` failing, and `updatedb` or `config:export`
failing for a package.

#### Running it by hand

Both scripts work outside CI, which is the quickest way to check a project is ready.
`UPDATE_DB_DUMP` skips Terminus and imports a local dump instead:

```bash
docker run -d --name autosec-db --network autosec cimg/mariadb:10.11
docker run --rm --network autosec -v "$PWD:/work" -w /work \
  -e DOCROOT=web -e UPDATE_DB_HOST=autosec-db \
  -e UPDATE_DB_DUMP=/work/db/site-db.sql.gz \
  cimg/php:8.4 bash -c '
    sudo apt-get update && sudo apt-get install -y mariadb-client
    ./vendor/fourkitchens/pots/scripts/updates/setup-drupal-env'
```

`UPDATE_DB_HOST`, `UPDATE_DB_PORT`, `UPDATE_DB_NAME`, `UPDATE_DB_USER` and
`UPDATE_DB_PASS` override the connection; the defaults match the CI sidecar.

#### Overriding

Both scripts follow the usual POTS override pattern — drop your own at
`.circleci/scripts/updates/setup-drupal-env` or
`.circleci/scripts/updates/apply-db-updates`. `setup-drupal-env` must leave
`DRUSH`, `DRUPAL_ROOT` and `CONFIG_SYNC_DIR` in `$UPDATE_STATE_DIR/env` for
`apply-db-updates` to source, and signal failure by creating `$UPDATE_STATE_DIR/disabled`.
`apply-db-updates` must print its Markdown summary on stdout, log to stderr, and always
exit 0.


## Automated minor composer updates

The second of the two automated update flows. Where AutoSec reacts to security advisories,
this one is routine maintenance: it applies the **minor and patch** releases available for
Drupal core and the project's other dependencies, runs the database updates they bring with
them, exports the resulting configuration, and opens a PR — every step AutoSec performs, with
one difference: which packages get picked.

Trigger it with its own POST, exactly like AutoSec:

```json
{
  "parameters": {
    "run-composer-updates-check": true,
    "update-data": "{\"ticketing_system\":\"clickup\",\"list_id\":\"901...\",\"client_id\":\"<uuid>\"}"
  }
}
```

Both flows share one job and one set of scripts; `scripts/updates/run-update <mode>` is the
entry point, where mode is `security` or `composer`.

### Minor only — and what that actually means

**A major version is never applied automatically.** Majors are breaking by definition and need
a person to plan and test them. That restriction is enforced by Composer's own semver logic
rather than by parsing version numbers, and it takes two conditions, both necessary:

| condition | what it rules out |
| --- | --- |
| `composer outdated --direct --minor-only` | targets the newest release **within the same major** |
| `latest-status == "semver-safe-update"` | anything the project's own constraints forbid |

Neither is sufficient alone. `--minor-only` on its own would still list a package the project
pins (a `10.2.*` constraint shows a 10.6 candidate but reports `update-possible`), and
`latest-status` on its own would let a major through on a constraint like `^1.0 || ^2.0`.
Because `--minor-only` includes patch releases, "minor" here means minor **and** patch.

Worth knowing, because it is easy to assume the opposite: this usually *does* update core.
On a site whose constraint is `~10.1` and which sits on 10.2.6, the run moves core to the
newest 10.x — not to 11.x. Majors that exist but were skipped are listed in the PR under
"Major upgrades available but not applied", so a waiting major upgrade is visible rather than
silently dropped.

`UPDATE_LEVEL=patch` narrows it further. `UPDATE_EXCLUDE` holds specific packages back.

#### The two exceptions, and the rule that guards them

Two situations are worse if a major is *not* taken, so a major can be applied — but only
under one hard rule.

| situation | mode |
| --- | --- |
| The advisory has no fix inside the installed major: the module was never patched on the branch this site pins | security |
| The installed branch is unsupported on drupal.org, so it will never receive another release of any kind | composer |

**The rule: a major is applied only when nothing newer remains inside the installed
major, and then exactly one major at a time.** Remaining majors stay in the PR's "Major
upgrades available but not applied" section for a person.

"Nothing newer remains" is answered from what the package has actually *published*, not
from what Composer currently offers — the two differ, and conflating them is how an
environment problem turns into an unwanted major upgrade. When a newer in-major release
exists but the run cannot reach it, the PR says which of these is in the way:

- the constraint in `composer.json` is tighter than the major → it is widened to
  `^MAJOR.0`, never past it;
- the constraint already allows it but the dependency graph pins it → reported with
  `composer why-not` output, and `composer.json` is left alone;
- `config.platform.php` blocks it → reported, with the instruction to raise the platform
  php (and the CI `php-version` with it) rather than cross a major.

**Drupal core never crosses a major automatically**, in either mode. A core major is a
planned project. When a core advisory has no fix left in the installed major, the run says
so in the PR and the ticket and leaves the site where it is, rather than taking the
decision on its own.

Set `UPDATE_ALLOW_UNSUPPORTED_MAJORS=NO` to switch the composer-mode exception off
entirely.

### Why packages are updated one at a time

The run updates each package with its own `composer update <package> --with-dependencies`
rather than a single bulk `composer update`. Two reasons:

1. **Attribution.** Each package gets its own composer commit and, where it changed
   configuration, its own config commit — so a reviewer can see which module caused which
   change.
2. **A full `composer update` can fail outright for unrelated reasons.** It re-resolves the
   whole dependency graph, so one advisory-blocked pin elsewhere in `composer.json` is enough
   to abort the entire run:
   ```
   Problem 1
     - Root composer.json requires drupal/foo 2.1.0 ... not loaded, because they are
       affected by security advisories ("SA-CONTRIB-2024-024")
   ```
   A per-package update is a *partial* update and does not re-resolve everything, so it
   sidesteps this. A package that cannot move (an exact pin, a conflict) is logged and
   skipped; the rest of the run continues.

### Choosing the packages yourself

Selection is a separate, overridable script, so a project can change the policy without
touching the orchestrator:

* `scripts/updates/select-packages-composer` — `composer outdated`, filtered as above
* `scripts/updates/select-packages-security` — `composer audit`, filtered to `drupal/*`

Both print one package name per line on stdout, log to stderr, and always exit 0. Drop your
own at `.circleci/scripts/updates/select-packages-<mode>` to override.
