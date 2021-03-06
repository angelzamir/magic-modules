#!/bin/bash

# This script configures the git submodule under magic-modules so that it is
# ready to create a new pull request.  It is cloned in a detached-head state,
# but its branch is relevant to the PR creation process, so we want to make
# sure that it's on a branch, and most importantly that that branch tracks
# a branch upstream.

set -e
set -x

shopt -s dotglob
cp -r magic-modules/* magic-modules-with-comment

ORIGINAL_PR_BRANCH="codegen-pr-$(cat ./mm-initial-pr/.git/id)"
pushd magic-modules-with-comment
echo "$ORIGINAL_PR_BRANCH" > ./original_pr_branch_name

# Check out the magic-modules branch with the same name as the current tracked
# branch of the terraform submodule.
BRANCH_NAME="$(git config -f .gitmodules --get submodule.build/terraform.branch)"
git checkout -b "$BRANCH_NAME"

if [ "$BRANCH_NAME" = "$ORIGINAL_PR_BRANCH" ]; then
  # There is no existing PR - this is the first pass through the pipeline and
  # we will need to create a PR using 'hub'.
  pushd build/terraform

  cat << EOF > ./downstream_body
$(git log -1 --pretty=%B)

<!-- This change is generated by MagicModules. -->
EOF

  git checkout -b "$BRANCH_NAME"
  TF_PR=$(hub pull-request -b "$TERRAFORM_REPO:master" -F ./downstream_body)
  popd

  cat << EOF > ./pr_comment 
I am a robot that works on MagicModules PRs!

I built this PR into one or more PRs on other repositories, and when those are closed, this PR will also be merged and closed.
depends: $TF_PR
EOF

else
  # This is the second-or-more pass through the pipeline - we need to overwrite
  # the codegen-pr-* branch with the new updated code to update the existing
  # PR, rather than create a new one.
  git branch -f "$ORIGINAL_PR_BRANCH"
  pushd build/terraform
  git branch -f "$ORIGINAL_PR_BRANCH"
  popd
  # Note - we're interested in HEAD~1 here, not HEAD, because HEAD is the
  # generated code commit.  :)
  cat << EOF >./pr_comment
I am (still) a robot that works on MagicModules PRs!

I just wanted to let you know that your changes (as of commit $(git rev-parse --short HEAD~1)) have been included in your downstream PRs.
EOF

fi
