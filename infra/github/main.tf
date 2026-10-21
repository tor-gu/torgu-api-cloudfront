# IAM roles assumed by this repo's GitHub Actions workflow
# (.github/workflows/deploy.yml) through OIDC.
#
# The OIDC provider is account-wide and lives in the shared aws-infra repo.
# Each role trusts only tokens whose sub claim names this repo and either a
# branch (readonly) or a GitHub environment (deploy). The prod environment
# requires approval, so the prod deploy role is unusable until a run on main
# is approved.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.region

  oidc_host = "token.actions.githubusercontent.com"

  stack_arns = {
    for env, cfg in var.envs : env =>
    "arn:aws:cloudformation:${local.region}:${local.account}:stack/${cfg.stack_name}/*"
  }
}

# --- readonly ---
# The plan job: compares each deployed stack with the repo. Any job on dev or
# main may use it, so it must not be able to change anything.

data "aws_iam_policy_document" "readonly_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/dev",
        "repo:${var.github_repo}:ref:refs/heads/main",
      ]
    }
  }
}

data "aws_iam_policy_document" "readonly" {
  statement {
    sid = "PlanStacks"
    actions = [
      "cloudformation:DescribeStacks",
      "cloudformation:GetTemplate",
    ]
    resources = values(local.stack_arns)
  }

  statement {
    sid       = "ValidateTemplate"
    actions   = ["cloudformation:ValidateTemplate"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "readonly" {
  name               = "${var.project}-gha-readonly"
  assume_role_policy = data.aws_iam_policy_document.readonly_trust.json
}

resource "aws_iam_role_policy" "readonly" {
  name   = "readonly"
  role   = aws_iam_role.readonly.id
  policy = data.aws_iam_policy_document.readonly.json
}

# --- deploy ---
# One role per environment: aws cloudformation deploy of that stack.

data "aws_iam_policy_document" "deploy_trust" {
  for_each = var.envs

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${var.github_repo}:environment:${each.key}"]
    }
  }
}

data "aws_iam_policy_document" "deploy" {
  for_each = var.envs

  # CloudFormation does the work as cfn_execution_role_arn; this role only
  # drives the change set. The template is small enough to pass inline, so
  # no artifact bucket is needed.
  statement {
    sid       = "PassExecutionRole"
    actions   = ["iam:PassRole"]
    resources = [var.cfn_execution_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["cloudformation.amazonaws.com"]
    }
  }

  statement {
    sid = "DeployStack"
    actions = [
      "cloudformation:CreateChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeStacks",
      "cloudformation:DescribeStackEvents",
      "cloudformation:DescribeStackResource",
      "cloudformation:GetTemplate",
    ]
    resources = [local.stack_arns[each.key]]
  }

  statement {
    sid = "Template"
    actions = [
      "cloudformation:GetTemplateSummary",
      "cloudformation:ValidateTemplate",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "deploy" {
  for_each = var.envs

  name               = "${var.project}-gha-deploy-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust[each.key].json
}

resource "aws_iam_role_policy" "deploy" {
  for_each = var.envs

  name   = "deploy"
  role   = aws_iam_role.deploy[each.key].id
  policy = data.aws_iam_policy_document.deploy[each.key].json
}
