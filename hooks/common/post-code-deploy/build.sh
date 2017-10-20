#!/bin/bash
#
# Cloud Hook (common): post-code-update
#
# The post-code-update hook runs in response to code commits.
# When you push commits to a Git branch, the post-code-update hooks runs for
# each environment that is currently running that branch. See
# ../README.md for details.
#
# Usage: post-code-update site target-env source-branch deployed-tag repo-url
#                         repo-type

site="$1"
target_env="$2"
source_branch="$3"
deployed_tag="$4"
repo_url="$5"
repo_type="$6"

# Grab Keys
# @see https://docs.acquia.com/acquia-cloud/files/system-files/private
source /mnt/gfs/home/$site/$target_env/nobackup/bashkeys.sh

if [ -z "$WAGNER_DRUSH_USER" ]
then
  echo "There are no drush keys set up for this environment."
  exit 1;
else
  drush @$site.$target_env ac-api-login --email=$WAGNER_DRUSH_USER --key=$WAGNER_DRUSH_KEY --endpoint=https://cloudapi.acquia.com/v1
fi

if [ -f /mnt/gfs/home/$site/$target_env/nobackup/skipbuild ]
then
  echo "The skip file was detected. You must run backups and build commands manually."
  exit 0;
fi

helper_script_dir="$( dirname $0 )/../../../scripts/acquia"

# Backing up current environment.
$helper_script_dir/wait_for_cloud_done.sh @$site.$target_env ac-database-instance-backup $site

# If we aren't on prod, pull in prod's db and files
if [ "$target_env" != 'prod' ]
then
  $helper_script_dir/wait_for_cloud_done.sh @$site.prod ac-database-copy $site $target_env
  $helper_script_dir/wait_for_cloud_done.sh @$site.prod ac-files-copy $target_env
fi

echo "Starting Build for $target_env"
if [ "$target_env" = 'dev' ]
then
  # If we are on dev, we want development tools enabled so we can work.
  drush @$site.$target_env local
else
  # Otherwise, all the other environments are built the same (including prod)
  drush @$site.$target_env prod
fi
echo "Ending Build for $target_env"