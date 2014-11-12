# -*- mode: Shell-script-*-
#!/usr/bin/bash
#
# Author: Mario Fernandez
#
# Initializes a git repository that is synchronized with an existing
# svn repository.
#
# Required environment variabless:
#  - GIT_SCRIPTS: directory where the git sync scripts are located
#  - GIT_SVN_SYNC_BASE: directory where the sync repositories are
# stored.
#  - GIT_SVN_SYNC_BRANCH: name of the branch that is synchronized with
# subversion.
#
# Usage: git-repository-from-svn.sh project svn_url git_url

if [ -z "${GIT_SCRIPTS}" ] || [ -z "${GIT_SVN_SYNC_BASE}" ] || [ -z "${GIT_SVN_SYNC_BRANCH}" ] ; then
    echo "The following variables are required for the synchronization to work: GIT_SCRIPTS GIT_SVN_SYNC_BASE GIT_SVN_SYNC_BRANCH"
    exit 1
fi

project=${1?No project name provided}
svn_url=${2?No svn url provided}
git_url=${3?No git url provided}
client=${GIT_SVN_SYNC_BASE}/${project}

if [ -d $client ] ; then
    echo "The folder for the git sync client already exists"
    exit 1
fi

# Sync client
git svn clone ${svn_url} ${client} || { echo "Could not clone svn repository at ${svn_url} in ${client}" ; exit 1; }

cd ${client}
git remote add origin ${git_url} || { echo "Could not set up server as remote from sync" ; exit 1; }
git branch ${GIT_SVN_SYNC_BRANCH} || { echo "Could not create svn sync branch" ; exit 1; }

for hook in pre-receive pre-commit ; do
    ln -s ${GIT_SCRIPTS}/sync-client-hooks/always-reject ${client}/.git/hooks/${hook}
done
