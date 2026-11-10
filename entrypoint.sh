#!/usr/bin/env bash
#
# Environment:
#   BRANCH              required: the pushed ref, e.g. refs/heads/release/2.3.0.
#   ADDON_DIR           required: the product's directory on the server.
#   SSH_PRIVATE_KEY     required: the deploy user's private key.
#   ADDON_ROOT          where the repository root goes in the release, e.g.
#                       upload/src/addons/Vendor/Name. Empty uploads the
#                       repository as it is.
#   DEPLOY_KNOWN_HOSTS  the server's known_hosts lines. Without it, the host
#                       key is taken from ssh-keyscan on every run.

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

SSH_USER=dbtech
HOST_NAME=dragonbytetech.com

fail() {
	echo "$*" >&2
	exit 1
}

BRANCH="${BRANCH:-}"
ADDON_DIR="${ADDON_DIR:-}"
ADDON_ROOT="${ADDON_ROOT:-}"

# Tags and hotfix branches drop everything from the first "-", so that
# hotfix/2.3.1-hotfix deploys as 2.3.1. Release branches keep the suffix.
case "$BRANCH" in
	refs/tags/*)
		version="${BRANCH#refs/tags/}"
		version="${version%%-*}"
		;;
	refs/heads/hotfix/*)
		version="${BRANCH#refs/heads/hotfix/}"
		version="${version%%-*}"
		;;
	refs/heads/*/*)
		version="${BRANCH#refs/heads/*/}"
		;;
	*)
		version=""
		;;
esac

# Both go into a command run on the server, so they are limited to
# characters that need no quoting there.
name_re='^[A-Za-z0-9][A-Za-z0-9._+-]*$'
[[ "$version" =~ $name_re ]] || fail "No valid version found in '$BRANCH'."
[[ "$ADDON_DIR" =~ $name_re ]] || fail "ADDON_DIR must be a single directory name, got '$ADDON_DIR'."
[ -n "${SSH_PRIVATE_KEY:-}" ] || fail "SSH_PRIVATE_KEY is empty."

releaseDir="vbec_products/$ADDON_DIR/$version"
workspaceDir="${GITHUB_WORKSPACE:-$PWD}"
cd "$(mktemp -d)"

mkdir deployment

if [ -n "$ADDON_ROOT" ];
then
	addon="deployment/$ADDON_ROOT"

	mkdir -p "$addon"
	cp -R "$workspaceDir"/* "$addon"

	if [ -d "$addon/_files" ]; then
		mkdir -p deployment/upload
		cp -R "$addon"/_files/* deployment/upload
		rm -rf "$addon/_files"
	fi

	if [ -d "$addon/_no_upload" ]; then
		cp -R "$addon"/_no_upload/* deployment
		rm -rf "$addon/_no_upload"
	fi

	if [ -f "$addon/build-server.json" ]; then
		# Read first, so that invalid JSON stops the deploy.
		commands="$(jq --raw-output '.exec // [] | .[]' "$addon/build-server.json")"

		cd deployment
		while IFS= read -r cmd; do
			[ -n "$cmd" ] || continue
			echo "+ $cmd"
			# Without stdin, so that a command can't consume the list.
			sh -c "$cmd" < /dev/null
		done <<< "$commands"
		cd ..
	fi

	rm -rf "$addon/.git"
	rm -rf "$addon/.github"
	rm -rf "$addon/_dev"
	rm -rf "$addon/_output"

else
	cp -R "$workspaceDir"/* deployment

	rm -rf "deployment/.git"
	rm -rf "deployment/.github"
fi


echo 'Setting up SSH...'

mkdir -p ~/.ssh
chmod 700 ~/.ssh
(
	umask 077
	printf '%s\n' "$SSH_PRIVATE_KEY" > ~/.ssh/deploy_key

	if [ -n "${DEPLOY_KNOWN_HOSTS:-}" ]; then
		printf '%s\n' "$DEPLOY_KNOWN_HOSTS" > ~/.ssh/deploy_known_hosts
	else
		echo "DEPLOY_KNOWN_HOSTS is not set, so the host key is trusted from ssh-keyscan." >&2
		ssh-keyscan "$HOST_NAME" > ~/.ssh/deploy_known_hosts
	fi
)

ssh_cmd="ssh -i $HOME/.ssh/deploy_key -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$HOME/.ssh/deploy_known_hosts"


echo "Deploying $version to $SSH_USER@$HOST_NAME:$releaseDir..."

$ssh_cmd "$SSH_USER@$HOST_NAME" "mkdir -p -- '$releaseDir'"
rsync --recursive --delete --stats -e "$ssh_cmd" deployment/ "$SSH_USER@$HOST_NAME:$releaseDir/"


printf -- '\033[32m Deployment successful! \033[0m\n'
printf -- '\n'
