# Circle CI Starter for Projects

This Composer package provides the starts for what you need to test and deploy
an hosted site on something like Acquia.

## Dependencies

This package expects your project to have the following support scaffolding to
run out of the box:

- phpcs.xml or phpcs.xml.dist
- package.json preferably with a .nvmrc
- several scripts in composer.json
- .gitignore files with cut lines in them to distinguish source from artifact.

Set up of the Circle tasks assumes you are doing this with a bot user. Please
ensure that the bot user you are using has account on both the github
organization where your site lives as well as the hosting provider. You will
need:
 - the ability to log in as the bot user in github and on the hosting provider
 - an SSH Key (private and public)
 - an api or machine token for the hosting tooling such as terminus or acli

## Installation

1. Install the package and copy over the template config.yml

    ```
    composer require fourkitchens/project_ci
    mkdir .circleci
    cp vendor/fourkitchens/project_ci/config.yml .circleci/config.yml
    ```
2. Push the changes to a public github branch.
3. Log in to https://app.circleci.com/
4. Navigate to the organization that your site's code lives under by clicking
   the icon in the top left corner where your name is and selecting the correct
   one.
5. Navigate to Projects
6. Find the Repo name for your site
7. Click the "Set Up Project" button next to it
8. Choose Fastest
9. Type in the branch you pushed your changes up to where the "git branch" icon
   is in the dialog.
10. Verify the wrench icon turns Green and lets you know it found a config.jon
11. Click "Set Up Project"

The first pass will always fail. Move on to configuration.
## Configure Environment

There are some configuration steps that are shared between hosting environments.
Make sure to check out the settings specific to the environment you are pushing
to.

### Shared

#### Deploy Bot Setup
A Deploy bot user will be needed. This tooling assumes Bender (the Four Kitchens
deploy bot) as the default, but does not provide any credentials you need to set
the tooling up. Ask a Web Chef about Bender, have the organization you are
working with create a new bot, or create the new bot for them using the steps
below. You will need to log in as this bot to do some of the configuration.

##### Create a Github Account for the Deploy Bot
1. Open a new browser instance or log out of your current github instance.
2. Go to https://github.com/join.
3. Type a user name, your email address, and a password. NOTE: Make sure the
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
5. Validate you see you see failed workflows.
6. Click on "Project Settings"
7. Click on "SSH Keys"
8. Navigate to "Additional SSH Keys"
9. Click "Add SSH Key"
10. Copy the contents of the private SSH Key you were provided (or generated)
    for the bot user into the Private Key field in the dialog that appears.
11. Verify that you have no extraneous spaces or newlines
12. Click "Add SSH Key" to close the dialog and accept the changes.
13. Note the Finger Print for future use. **Note:** you can check to make sure
    the file was copied correctly by validating that the fingerprint in circleci
    is the same as what is displayed by the command
    `ssh-keygen -l -E md5 -f id_rsa` where idrsa is the filename of your key.

#### Get a Github Token
You must have a github token so the deploy bot can post comments back to commits
or pull requests. This allows it to provide links and information about the
environments it created.

If you skipped here, make sure you follow steps 1-6 of "Configure an SSH Key" to
get to Circle's Project Settings"

1. In a new browser instance, log in to Github as the Deploy bot.
2. Follow the instructions for [creating a personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token#creating-a-token)
3. Choose just repo:status, repo_deployment and public_repo for scopes
4. Save the access token securely so you will have access to it. It will only
   be displayed once.

#### Configure Environment Variables

Here you will configure the common environment variables. Hosting specific
variables and steps will be provided farther down. The variables to configure
are as follows.

* `GITHUB_TOKEN` A github access token so the bot user can comment back on the
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
9. Type the email address associated with the deploy bot into "Value"
10. Click "Add Environment Variable" to accept the changes.

### Pantheon

* `SITE_NAME`: The Pantheon site id used to run terminus commands.
* `TERMINUS_TOKEN`: The Pantheon Machine Token used to operate terminus.

#### Create a Pantheon Account for your Deploy Bot

For Pantheon hosted sites, we need an account for our deploy bot so that our
deployments are linked to any one pantheon user.

1. Log in as an administrator of your Pantheon Organization.
2. Click your user's name in the top right corner of the dashboard
3. Navigate down to the organization name you want to create a user for.
4. Click the "People" tab.
5. Click the "Add User" button
6. Select "Team Member" for Role
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
2. Save the machine token securely so you will have access to it. It will only
   be displayed once.

#### Configure More CircleCi Environment Variables
1. Navigate back to your CircleCI -> Project Settings -> Enviornment Variables
   browser instance.
2. Click "Add Environment Variable"
3. Type "SITE_NAME" in the name
4. Type the site id (or `TERMINUS SITE ID`) of your Pantheon site into "Value".
    **Note:** you can find the site id by looking at the site's dashboard in
    pantheon. If you click the "Visit Site" button on any environment the url is
    in the format of
    `https://{{TERMINUS ENV}}-{{TERMINUS SITE}}.pantheonsite.io/`
5. Click "Add Environment Variable" to accept the changes.
6. Click "Add Environment Variable"
7. Type "TERMINUS_TOKEN" in the name
8. Copy the machine token value you saved earlier into "Value"
9. Click "Add Environment Variable" to accept the changes.

### Acquia

#### Create a Acquia Account for your Deploy Bot

**TODO: FILL OUT THIS BIT**

#### Set up SSH Key

Your bot will need an ssh key configured to be able to push commits to Acquia.
Use the public key of the pair generated in the "Configure an SSH Key" section.

Log out of your Acquia account or use a separate browser instance to follow
the instructions from Acquia to [Add a public key to an Acquia profile](https://docs.acquia.com/cloud-platform/manage/ssh/enable/add-key/).

#### Configure More CircleCi Environment Variables
* `SITE_NAME`: The acquia site id used to run acquia cloud api commands.
* `ACQUIA_REALM: the Cloud API Realm. Usually "prod" or "devcloud".
* `ACQUIA_REPO`: The acquia git repo.

#### Configure More CircleCi Environment Variables
1. Navigate back to your CircleCI -> Project Settings -> Enviornment Variables
   browser instance.
1. Click "Add Environment Variable"
2. Type "ACQUIA_REPO" in the name
3. Type the Acquia Repo url into "Value".
   **TODO:** FLESH THIS OUR MORE WITH HELP ON HOW TO GET IT
4. Click "Add Environment Variable" to accept the changes.
1. Click "Add Environment Variable"
2. Type "ACQUIA_REALM" in the name
3. Type the Acquia Realm id into "Value".
   **TODO:** FLESH THIS OUR MORE WITH HELP ON HOW TO GET IT
4. Click "Add Environment Variable" to accept the changes.
5. Click "Add Environment Variable"
6. Type "SITE_NAME" in the name
7. Copy the acquia site id into "Value"
   **TODO:** FLESH THIS OUR MORE WITH HELP ON HOW TO GET IT
8. Click "Add Environment Variable" to accept the changes.

## Configure CircleCI config.yml

**TODO:** Add stuff in here about parameters

## Configure Composer.json

**TODO:** Add what default scripts need to be here so that this will function.

## Configure Scripts
**TODO:** Be more verbose about what scripts are avaiblible for configuration
3. Customize any scripts by copying a script from `./vendor/fourkitchens/project_ci/scripts` to `.circleci/scripts`
4. Customize the web root directory if you must by changing all instances of `default: "docroot"` to the value you need.
5. Make sure you have a `.nvmrc` file with a valid verison of node at the root
   of the project.
