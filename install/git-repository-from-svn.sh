 # -*- mode: Shell-script-*-
#!/usr/bin/bash
#
# Author: Mario Fernandez
#
# Initializes a git repository that is synchronized with an existing
# svn repository.
#
# Required environment variables:
#  - GIT_SCRIPTS: directory where the git sync scripts are located
#  - GIT_SVN_SYNC_BASE: directory where the sync repositories are
# stored.
#
# Optional environment variables:
# - GIT_SVN_SYNC_BRANCH: name of the branch that is synchronized with
# subversion (default = svn-sync).
# - GIT_SVN_LAYOUT: SVN layout options to override (default --stdlayout)
# - GIT_SVN_AUTHORS: authors-file option (default none)
#
# Usage: git-repository-from-svn.sh project svn_url git_url

if [ -z "${GIT_SCRIPTS}" ] || [ -z "${GIT_SVN_SYNC_BASE}" ] ; then
    echo "The following variables are required for the synchronization to work: GIT_SCRIPTS GIT_SVN_SYNC_BASE"
    exit 1
fi

# Set optional variables
: ${GIT_SVN_SYNC_BRANCH:="svn-sync"}
: ${GIT_SVN_LAYOUT:="--stdlayout"}
[ -z "${GIT_SVN_AUTHORS}" ] || GIT_SVN_AUTHORS="--authors-file=${GIT_SVN_AUTHORS}"
: ${GIT_HOOK_CMD:="ln -s"}
: ${GIT_SVN_REMOTE:="svn"}
: ${GIT_PUSH:=1}

project="${1?No project name provided}"
svn_url="${2?No svn url provided}"
git_url="${3?No git url provided}"
client="${GIT_SVN_SYNC_BASE}/${project}"

if [ -d "$client" ] ; then
    echo "The folder for the git sync client already exists"
    exit 1
fi

# Sync client
git svn clone ${GIT_SVN_LAYOUT} ${GIT_SVN_AUTHORS} --prefix "${GIT_SVN_REMOTE}/" "${svn_url}" "${client}" \
    || { echo "Could not clone svn repository at ${svn_url} in ${client}" ; exit 1; }

cd "${client}"

# Convert SVN tags and branches for remote Git
git for-each-ref --format="%(refname:short) %(objectname)" refs/remotes/${GIT_SVN_REMOTE} \
| while read BRANCH REF
do
    NAME=${BRANCH##*/}
    BODY="$(git log -1 --format=format:%B $REF)"

    echo "ref=$REF parent=$(git rev-parse $REF^) name=$NAME body=$BODY" >&2

    # Ignore branches with revision suffix
    # TODO: Implement an ignore regexp option
    if ! [[ $NAME =~ ^.+@[0-9]+$ ]]; then
        case ${BRANCH#*/} in
        tags/*)
            echo "Converting tag $NAME as local Git tag..."
            git tag -a -m "$BODY" $NAME $REF^ \
            || { echo "Could not convert tag $NAME" ; exit 1; }
            ;;
        trunk)
            echo "Preserving the trunk"
            ;;
        *)
            echo "Copying branch $NAME as local Git branch..."
            git branch $NAME $BRANCH \
            || { echo "Could not convert branch $NAME" ; exit 1; }
            ;;
        esac
    fi
    # Delete all svn branches, but trunk
    if ! [[ $NAME =~ ^trunk$ ]]; then
        git branch -r -d $BRANCH \
        || { echo "Could not delete branch $NAME" ; exit 1; }
    fi
done

# Add the remote Git repo and push if requested
git remote add origin ${git_url} || { echo "Could not set up server as remote from sync" ; exit 1; }
if [ ${GIT_PUSH} -eq 1 ]; then
    git push --all
    git push --tags
fi

git branch ${GIT_SVN_SYNC_BRANCH} || { echo "Could not create svn sync branch" ; exit 1; }

for hook in pre-receive pre-commit ; do
    ${GIT_HOOK_CMD} "${GIT_SCRIPTS}/sync-client-hooks/always-reject" "${client}/.git/hooks/${hook}"
done
