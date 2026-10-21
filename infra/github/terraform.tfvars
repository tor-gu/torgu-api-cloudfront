project     = "torgu-api-cloudfront"
github_repo = "tor-gu/torgu-api-cloudfront"

envs = {
  dev = {
    stack_name = "TorguApiTest"
  }
  prod = {
    stack_name = "TorguApi"
  }
}

cfn_execution_role_arn = "arn:aws:iam::490461464130:role/aws-sam-cli-managed-prod-CloudFormationExecutionR-Q7T0TM3BM99D"
