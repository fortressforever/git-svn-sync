# -*- mode: Shell-script-*-
#!/usr/bin/bash
#
# The changes from the svn repo are pulled into GIT_SVN_SYNC_BRANCH, and then
# the specified commit(s) from git are cherry-picked into it and committed to
# subversion.
#
# Required environment variabless:
#  - GIT_SCRIPTS: directory where the git sync scripts are located
#  - GIT_SVN_SYNC_BASE: directory where the sync repositories are
# stored.
#  - GIT_SVN_SYNC_BRANCH: name of the branch that is synchronized with
# subversion.
#  - GIT_SVN_SYNC_EMAIL: email to send error reports to
#
# Usage: git-mirror-to-svn.sh project_name commit_sha

destination=${GIT_SVN_SYNC_EMAIL}
project=${1?No project provided}
commits_to_pick=${2?No commits provided}
location=${GIT_SVN_SYNC_BASE}/${project}

if [ ! -d $location ] ; then
    echo "The folder where the synchronization repository is supposed to be does not exist"
    exit 1
fi

unset GIT_DIR
cd $location

report () {
    echo $1
    sh ${GIT_SCRIPTS}/report-error.sh $destination "$project" "$1" "$commits_to_pick" "$2"
}

# Get changes from svn
echo "Switching to SVN branch"
git checkout ${GIT_SVN_SYNC_BRANCH} || { report "Could not switch to sync branch" ; exit 1; }
echo "Pulling any SVN changes"
git svn rebase

if [ -n "$(git status --porcelain)" ] ; then
    echo "Workspace is dirty. Clean it up (i.e with git reset --hard HEAD) before continuing"
    exit 1
fi

git fetch origin
git cherry-pick -Xtheirs ${commits_to_pick} || { report "Could not cherry pick from git repository" ; exit 1; }

git svn dcommit || { report "Could not send changes to svn repository" ; exit 1; }
