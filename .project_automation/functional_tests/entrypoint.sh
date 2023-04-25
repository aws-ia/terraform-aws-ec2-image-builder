#!/bin/bash -ex

## NOTE: paths may differ when running in a managed task. To ensure behavior is consistent between
# managed and local tasks always use these variables for the project and project type path
PROJECT_PATH=${BASE_PATH}/project
PROJECT_TYPE_PATH=${BASE_PATH}/projecttype

cd ${PROJECT_PATH}

#********** Checkov Analysis *************
echo "Running Checkov Analysis"
terraform init
terraform plan -out tf.plan
terraform show -json tf.plan  > tf.json 
checkov 

#********** Terratest execution **********
echo "Running Terratest"
cd test
rm -f go.mod
go mod init github.com/aws-ia/terraform-project-ephemeral
go mod tidy
go install github.com/gruntwork-io/terratest/modules/terraform
go test -timeout 45m

#********** Terratest execution **********
cd ${PROJECT_PATH}
echo "Building readme.md file"
UPDATE_BRANCH="ephemeral_readme-updates" 

export GH_DEBUG=1
REMOTE=$(git remote -v | awk '{print $2}' | head -n 1)
git remote remove origin
git remote add origin ${REMOTE}
git fetch --all

git push origin -d $UPDATE_BRANCH || true
git checkout -b "$UPDATE_BRANCH"
terraform-docs --lockfile=false ./

if [ -n "${BASE_PATH}" ]
then
  git add . --all
  git commit -m "(automated) Updates from project type"
  git push -f --set-upstream origin $UPDATE_BRANCH
  gh pr create --title "Updates from functional tests " --body "_This is an automated PR incorporating updates to this project's readme.md file. Please review and either approve/merge or reject as appropriate_"
else
  echo "Local build mode (skipping git commit)"
fi