# -*- mode: Shell-script-*-
#!/usr/bin/bash
#
# Github SVN mirror is used to merge each commit to SVN
# This is done to attempt to avoid line ending conflicts
# that tend to pop up when using git-svn
#
# Required environment variables:
#  - GIT_SCRIPTS: directory where the git sync scripts are located
#  - GIT_SVN_SYNC_BASE: directory where the sync repositories are
# stored.
#  - GIT_SVN_SYNC_GIT_PATH: directory where the git repo is checked out,
# relative to GIT_SVN_SYNC_BASE/$project_name/
#  - GIT_SVN_SYNC_SVN_PATH: directory where the svn repo is checked out,
# relative to GIT_SVN_SYNC_BASE/$project_name/
#  - GIT_SVN_SYNC_EMAIL: email to send error reports to
#
# Usage: github-svn-mirror.sh project_name

destination=${GIT_SVN_SYNC_EMAIL}
project=${1?No project provided}
location=${GIT_SVN_SYNC_BASE}/${project}
git_location=${location}/${GIT_SVN_SYNC_GIT_PATH}
svn_location=${location}/${GIT_SVN_SYNC_SVN_PATH}

if [ ! -d $git_location ] ; then
	echo "The folder where the git repository is supposed to be does not exist"
	exit 1
fi

if [ ! -d $svn_location ] ; then
	echo "The folder where the svn repository is supposed to be does not exist"
	exit 1
fi

report () {
	echo $1
	sh ${GIT_SCRIPTS}/report-error.sh $destination "$project" "$1"
}

# Get changes from svn
echo "Updating SVN"
svn update $svn_location || { report "Could not update SVN" ; exit 1; }

if [ -n "$(svn status $svn_location)" ] ; then
	report "Workspace is dirty. Clean it up before continuing"
	exit 1
fi

git_working_copy_revision=$(svnversion $git_location)
git_head_revision=$(svn info -r HEAD $git_location | awk '/Last Changed Rev:/ { print $4 }')
revisions_to_merge=$(expr $git_head_revision - $git_working_copy_revision)
echo "Git repository is at r$git_working_copy_revision (Upstream: r$git_head_revision)"

if [ $revisions_to_merge -le 0 ] ; then
	echo "Nothing to merge"
	exit 1
fi

revision_to_merge=$git_working_copy_revision
while [ $revision_to_merge -le $git_head_revision ]; do
	commit_msg=$(svn log $git_location --xml -r $revision_to_merge | sed -n -e '/<msg>/,/<\/msg>/{ s/<msg>\(.*\)/\1/; s/\(.*\)<\/msg>/\1/; p; }')
	commit_hash=$(svn propget git-commit --revprop -r $revision_to_merge $git_location 2>&-)

	if [ -n "$commit_msg" ]; then
		echo "Merging r$revision_to_merge ($commit_hash)"
		svn merge --accept theirs-full --ignore-ancestry -c $revision_to_merge $git_location $svn_location || { report "Could not merge r$revision_to_merge ($commit_hash) from git repository to svn repository" ; exit 1; }
		svn commit $svn_location -m "$commit_msg" || { report "Could not commit r$revision_to_merge ($commit_hash) to svn repository" ; exit 1; }
	fi

	let revision_to_merge=$revision_to_merge+1
done

echo "All merges successful, updating git repository"
svn update $git_location || { report "Could not update git repository"; exit 1; }
