variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  description = "Prefix for the role names"
  type        = string
}

variable "github_repo" {
  description = "owner/name of the GitHub repository whose workflows may assume the roles"
  type        = string
}

variable "envs" {
  description = "Deploy environments, keyed by GitHub environment name (prod deploys from main, dev from dev)"
  type = map(object({
    stack_name = string # the CloudFormation stack of torgu-api-cloudfront.yaml
  }))
}

variable "cfn_execution_role_arn" {
  description = "Role CloudFormation assumes to change the stacks (shared with the SAM projects)"
  type        = string
}
