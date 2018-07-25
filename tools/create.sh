#!/bin/bash
export LANG=ja_JP.UTF-8

#ApplicationRoleName:
application_rolename="role-for-app-of-lambda-pipeline-demo"
#BucketName:
bucket="mfurukawa-lambda-sample-tokyo"
#BuildImage:
buildimage="abacl7/go-devenv:latest"
#GitHubAccount:
github_account="abacl7"
#GitHubBranch:
github_branch="master"
#GitHubRepository:
github_repo="https://github.com/abacl7/lambda-sample"
#GitHubToken:
github_token=""
#LambdaFunctionName:
function_name="hello"
#PipelineRoleName:
pipeline_rolename="role-for-cicd-of-lambda-pipeline-demo"
#Region:
region="ap-northeast-1"
#ServiceName:
service_name="lambda-sample"
#StageName:
stage="dev"

tools_dir=`dirname $0`
cf_dir="${tools_dir}/../CloudFormation"
stack_base_name="${service_name}-stack"

shopt -s expand_aliases
if sed --version 2>/dev/null | grep -q GNU; then
  alias sedi='sed -i '
else
  alias sedi='sed -i "" '
fi

usage() {
  echo "$0: --profile PROFILE_NAME --token GITHUB_TOKEN"
  exit 1
}

missing_args() {
  echo "Error: option requires an argument -- $1" 1>&2
  exit 1
}

if [[ $# -eq 0 ]]; then
  usage
fi

for opt in "$@"; do
  case "$opt" in
    '--profile' )
      if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
        missing_args $opt
      fi
      profile="$2"
      aws_options="${aws_options} --profile ${profile}"
      shift 2
      ;;
    '--token' )
      if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
        missing_args $opt
      fi
      github_token="$2"
      shift 2
      ;;
    'usage' | 'help' )
      usage
      ;;
  esac
done

if [[ -z "$profile" ]]; then
  usage
fi

create_stack() {
  stack_name=$1
  shift
  template_body=$1
  shift
  [[ $# -ge 1 ]] && parameters="--parameters $1" || parameters=""
  aws_command="aws cloudformation create-stack --region $region $aws_options --stack-name $stack_name --template-body $template_body $parameters"
  echo "AWS Command(${LINENO}): ${aws_command}"
  result=`${aws_command}`
  stack_id=`echo $result | jq -r '.StackId'`
  stack_status=''
  while [ 'CREATE_COMPLETE' != "$stack_status" ] ; do
    result=`aws cloudformation describe-stacks --region $region $aws_options --stack-name $stack_name`
    stack_status=`echo $result | jq -r '.Stacks[].StackStatus'`
    echo "StackStatus: ${stack_status}"
    if [[ 'CREATE_FAILED' == "$stack_status" ]] || [[ 'ROLLBACK_COMPLETE' == "$stack_status" ]] || [[ 'ROLLBACK_FAILED' == "$stack_status" ]] || [[ 'ROLLBACK_IN_PROGRESS' == "$stack_status" ]]; then
      echo "create failed"
      exit 1
    fi
    sleep 10
  done
}

aws_command_inspector() {
  echo "Result: $2"
  echo "Status: $1"
}

echo "create a bucket for CFn templates on S3"
aws s3 mb s3://${bucket} --region ${region} ${aws_options}
aws s3 cp ${cf_dir}/ s3://${bucket}/ --exclude "*" --include "*.yml" --recursive --region $region $aws_options

echo "${stack_base_name}-mini-${region} invoke"
create_stack "${stack_base_name}-main-${region}" "file://${cf_dir}/cf-base.yml" \
      "ParameterKey=ApplicationRoleName,ParameterValue=${application_rolename} \
      ParameterKey=BucketName,ParameterValue=${bucket} \
      ParameterKey=BuildImage,ParameterValue=${buildimage} \
      ParameterKey=GitHubAccount,ParameterValue=${github_account} \
      ParameterKey=GitHubBranch,ParameterValue=${github_branch} \
      ParameterKey=GitHubRepository,ParameterValue=${github_repo} \
      ParameterKey=GitHubToken,ParameterValue=${github_token} \
      ParameterKey=LambdaFunctionName,ParameterValue=${function_name} \
      ParameterKey=PipelineRoleName,ParameterValue=${pipeline_rolename} \
      ParameterKey=Region,ParameterValue=${region} \
      ParameterKey=ServiceName,ParameterValue=${service_name} \
      ParameterKey=StageName,ParameterValue=${stage} \
      --capabilities CAPABILITY_NAMED_IAM"


aws_command="aws cloudformation describe-stacks --region ${region} ${aws_options} --stack-name ${stack_base_name}-main-${region}"
echo "AWS Command(${LINENO}): ${aws_command}"
result=`${aws_command}`
if [[ $? -eq 0 ]]; then
  CodePipeline4CI=`echo $result | jq --arg key "CodePipeline4CI" -r '.Stacks[].Outputs[] | select(.OutputKey == $key).OutputValue'`
else
  aws_command_inspector "$?" "${result}"
fi

echo "stack exec finished."
