#!/bin/bash
# Show what deploying the repo's template and parameters to $STACK_NAME would
# change: diffs of the parameters and the template against the deployed
# stack. Read-only (DescribeStacks, GetTemplate). Writes markdown to stdout.
set -euo pipefail

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Parameters[].[ParameterKey,ParameterValue]' --output text |
    awk -F'\t' '{print $1 "=" $2}' | sort > "$work/deployed.params"
pipeline/params.sh "$ENV" | sort > "$work/repo.params"

aws cloudformation get-template --stack-name "$STACK_NAME" \
    --query TemplateBody --output text > "$work/deployed.yaml"

echo "## Plan for $STACK_NAME ($ENV)"
for kind in params yaml; do
    case $kind in
        params) title=Parameters; repo=$work/repo.params ;;
        yaml)   title=Template;   repo=$TEMPLATE ;;
    esac
    echo "### $title"
    if diff -q "$work/deployed.$kind" "$repo" > /dev/null; then
        echo "No changes."
    else
        echo '```diff'
        diff -u --label deployed --label repo "$work/deployed.$kind" "$repo" || true
        echo '```'
    fi
done
