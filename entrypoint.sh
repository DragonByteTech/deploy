#!/usr/bin/env bash

# Exit on error. Append "|| true" if you expect an error.
set -o errexit  # same as -e
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail

SSH_USER=dragonb
HOST_NAME=dragonbyte-tech.com

if [[ $BRANCH =~ ^refs/tags/.* ]];
then
	version=$(echo "$BRANCH" | sed 's#refs/tags/##')

	# Now update the version variable with the hotfix removed as we don't want that going forward
	version=$(echo "$version" | sed 's#[-hotfix].*$##')

else
	branch=`echo $BRANCH | cut -d/ -f3`
	version=`echo $BRANCH | cut -d/ -f4`

	if [[ $branch == hotfix ]];
	then
		# Now update the version variable with the hotfix removed as we don't want that going forward
		version=$(echo "$version" | sed 's#[-hotfix].*$##')
	fi
fi

if [ -z "$version" ];
then
  echo "No valid version found." >&2
  exit 1
fi

cd ..

mkdir deployment

if [ ! -z "$ADDON_ROOT" ];
then
	releaseDir="vbec_products/$ADDON_DIR/$version"
	addonDir="$releaseDir/$ADDON_ROOT"

	mkdir -p deployment/$ADDON_ROOT
	cp -R workspace/* deployment/$ADDON_ROOT

	if [ -d deployment/$ADDON_ROOT/_files ]; then
		cp -R deployment/$ADDON_ROOT/_files/* deployment/upload
		rm -rf deployment/$ADDON_ROOT/_files
	fi
	
	if [ -d deployment/$ADDON_ROOT/_no_upload ]; then
		cp -R deployment/$ADDON_ROOT/_no_upload/* deployment
		rm -rf deployment/$ADDON_ROOT/_no_upload
	fi

	if [ -f deployment/$ADDON_ROOT/build-server.json ]; then
		cd deployment

		while read -r cmd; do
			sh -c "${cmd}"
		done < <(cat $ADDON_ROOT/build-server.json | jq --raw-output '.exec[]')

		cd ..
	fi

	rm -rf deployment/$ADDON_ROOT/.git
	rm -rf deployment/$ADDON_ROOT/.github
	rm -rf deployment/$ADDON_ROOT/_dev
	rm -rf deployment/$ADDON_ROOT/_output

else
	releaseDir="vbec_products/$ADDON_DIR/$version"
	cp -R workspace/* deployment

	rm -rf "deployment/.git"
	rm -rf "deployment/.github"
fi


printf -- 'Setting up SSH... '

mkdir ~/.ssh
touch ~/.ssh/known_hosts

mkdir /root/.ssh
touch /root/.ssh/known_hosts

echo "$SSH_PRIVATE_KEY" > /root/.ssh/deploy_key
echo "$SSH_PUBLIC_KEY" > /root/.ssh/deploy_key.pub

echo "$SSH_PRIVATE_KEY" > ~/.ssh/deploy_key
echo "$SSH_PUBLIC_KEY" > ~/.ssh/deploy_key.pub

chmod 700 ~/.ssh
chmod 600 ~/.ssh/known_hosts
chmod 600 ~/.ssh/deploy_key
chmod 600 ~/.ssh/deploy_key.pub

chmod 700 /root/.ssh
chmod 600 /root/.ssh/known_hosts
chmod 600 /root/.ssh/deploy_key
chmod 600 /root/.ssh/deploy_key.pub


printf -- 'Recording known host... '

ssh-keyscan $HOST_NAME >> ~/.ssh/known_hosts
ssh-keyscan $HOST_NAME >> /root/.ssh/known_hosts


printf -- 'Adding deploy key... '

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/deploy_key


# $HOST_NAME is used in the above as well as in the below; that's why it is an env

printf -- 'Cleaning up old deployment... '
sh -c "ssh $SSH_USER@$HOST_NAME 'rm -rf $releaseDir && mkdir -p $releaseDir'"


printf -- 'Deploying project... '
sh -c "rsync --progress --verbose --recursive --delete-after --quiet deployment/ $SSH_USER@$HOST_NAME:$releaseDir"



printf -- '\033[32m Deployment successful! \033[0m\n'
printf -- '\n'
