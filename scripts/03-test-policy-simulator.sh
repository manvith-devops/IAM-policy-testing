#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# 03-test-policy-simulator.sh
# Assignment 18 - Test IAM Permissions with the Policy Simulator
#
# What the IAM Policy Simulator does:
#   Evaluates whether a user/role is allowed or denied a specific action,
#   WITHOUT actually performing the action. Safe to run at any time.
#
# This script runs a full test suite:
#   ✅ Actions that SHOULD be allowed
#   🚫 Actions that SHOULD be denied
#
# Run AFTER 01-deploy-iam.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

# ─── Config ───────────────────────────────────────────────────────────────────
REGION="us-east-1"
PROJECT_NAME="assignment18"
STACK_NAME="assignment18-iam"

# Get the user ARN from the CloudFormation stack outputs
echo "🔍 Looking up developer-test user ARN from CloudFormation..."
USER_ARN=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='DeveloperUserArn'].OutputValue" \
  --output text 2>/dev/null)

if [ -z "$USER_ARN" ]; then
  echo "❌ Could not find the IAM user. Make sure 01-deploy-iam.sh ran successfully."
  exit 1
fi

echo "✅ Testing user: $USER_ARN"
echo ""

# ─── Helper Function ──────────────────────────────────────────────────────────
# Tests one action and prints PASS or FAIL
# Arguments: ACTION  RESOURCE  DESCRIPTION  EXPECTED_RESULT(allowed/denied)
run_test() {
  local ACTION=$1
  local RESOURCE=$2
  local DESCRIPTION=$3
  local EXPECTED=$4
  local CONTEXT_ENTRIES=$5  # optional JSON for condition keys

  # Build the CLI command
  if [ -n "$CONTEXT_ENTRIES" ]; then
    RESULT=$(aws iam simulate-principal-policy \
      --policy-source-arn "$USER_ARN" \
      --action-names "$ACTION" \
      --resource-arns "$RESOURCE" \
      --context-entries "$CONTEXT_ENTRIES" \
      --region "$REGION" \
      --query "EvaluationResults[0].EvalDecision" \
      --output text 2>/dev/null)
  else
    RESULT=$(aws iam simulate-principal-policy \
      --policy-source-arn "$USER_ARN" \
      --action-names "$ACTION" \
      --resource-arns "$RESOURCE" \
      --region "$REGION" \
      --query "EvaluationResults[0].EvalDecision" \
      --output text 2>/dev/null)
  fi

  # Format the result
  if [ "$RESULT" == "allowed" ]; then
    STATUS_ICON="✅ ALLOWED"
  else
    STATUS_ICON="🚫 DENIED "
  fi

  # Check if result matches what we expected
  if [ "$RESULT" == "$EXPECTED" ]; then
    VERDICT="  ✔ PASS"
  else
    VERDICT="  ✘ FAIL  (expected: $EXPECTED, got: $RESULT)"
  fi

  printf "  %-50s %s%s\n" "$DESCRIPTION" "$STATUS_ICON" "$VERDICT"
}

# ─── Test Suite ───────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════════════════════════════"
echo "  Assignment 18 - IAM Policy Simulator Test Results"
echo "════════════════════════════════════════════════════════════════════"

echo ""
echo "── S3 TESTS ─────────────────────────────────────────────────────────"
run_test \
  "s3:ListAllMyBuckets" \
  "arn:aws:s3:::*" \
  "Can list all S3 buckets" \
  "allowed"

run_test \
  "s3:GetObject" \
  "arn:aws:s3:::yefter-dev-bucket/file.txt" \
  "Can read S3 objects (basic)" \
  "allowed"

run_test \
  "s3:DeleteObject" \
  "arn:aws:s3:::yefter-dev-bucket/file.txt" \
  "Cannot delete S3 objects [SHOULD BE DENIED]" \
  "denied"

run_test \
  "s3:DeleteBucket" \
  "arn:aws:s3:::yefter-dev-bucket" \
  "Cannot delete S3 bucket [SHOULD BE DENIED]" \
  "denied"

run_test \
  "s3:PutObject" \
  "arn:aws:s3:::yefter-dev-bucket/file.txt" \
  "Cannot write to S3 [SHOULD BE DENIED]" \
  "denied"

run_test \
  "s3:PutBucketPolicy" \
  "arn:aws:s3:::yefter-dev-bucket" \
  "Cannot change bucket policy [SHOULD BE DENIED]" \
  "denied"

echo ""
echo "── EC2 TESTS ────────────────────────────────────────────────────────"
run_test \
  "ec2:DescribeInstances" \
  "*" \
  "Can describe EC2 instances" \
  "allowed"

run_test \
  "ec2:DescribeVpcs" \
  "*" \
  "Can describe VPCs" \
  "allowed"

run_test \
  "ec2:DescribeSubnets" \
  "*" \
  "Can describe subnets" \
  "allowed"

# Test EC2 t2.micro launch - passing instance type as context key
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
run_test \
  "ec2:RunInstances" \
  "arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/*" \
  "Can launch t2.micro instance" \
  "allowed" \
  "[{\"contextKeyName\":\"ec2:InstanceType\",\"contextKeyValues\":[\"t2.micro\"],\"contextKeyType\":\"string\"}]"

# Test EC2 t2.large launch - should be denied
run_test \
  "ec2:RunInstances" \
  "arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/*" \
  "Cannot launch t2.large instance [SHOULD BE DENIED]" \
  "denied" \
  "[{\"contextKeyName\":\"ec2:InstanceType\",\"contextKeyValues\":[\"t2.large\"],\"contextKeyType\":\"string\"}]"

# Test t3.micro - should be allowed
run_test \
  "ec2:RunInstances" \
  "arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/*" \
  "Can launch t3.micro instance" \
  "allowed" \
  "[{\"contextKeyName\":\"ec2:InstanceType\",\"contextKeyValues\":[\"t3.micro\"],\"contextKeyType\":\"string\"}]"

# Test m5.large - should be denied
run_test \
  "ec2:RunInstances" \
  "arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/*" \
  "Cannot launch m5.large instance [SHOULD BE DENIED]" \
  "denied" \
  "[{\"contextKeyName\":\"ec2:InstanceType\",\"contextKeyValues\":[\"m5.large\"],\"contextKeyType\":\"string\"}]"

echo ""
echo "── IAM TESTS (Boundary Enforcement) ────────────────────────────────"
run_test \
  "iam:CreateUser" \
  "arn:aws:iam::${ACCOUNT_ID}:user/*" \
  "Cannot create IAM users [BOUNDARY BLOCKS]" \
  "denied"

run_test \
  "iam:AttachUserPolicy" \
  "arn:aws:iam::${ACCOUNT_ID}:user/*" \
  "Cannot attach IAM policies [BOUNDARY BLOCKS]" \
  "denied"

run_test \
  "iam:CreateRole" \
  "arn:aws:iam::${ACCOUNT_ID}:role/*" \
  "Cannot create IAM roles [BOUNDARY BLOCKS]" \
  "denied"

echo ""
echo "── REGION RESTRICTION TESTS ─────────────────────────────────────────"
run_test \
  "s3:GetObject" \
  "arn:aws:s3:::yefter-dev-bucket/file.txt" \
  "Can access S3 in us-east-1 (allowed region)" \
  "allowed" \
  "[{\"contextKeyName\":\"aws:RequestedRegion\",\"contextKeyValues\":[\"us-east-1\"],\"contextKeyType\":\"string\"}]"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  ✅ Tests complete!"
echo ""
echo "  📌 For deeper testing with tag conditions, use the AWS Console:"
echo "     https://policysim.aws.amazon.com/"
echo "     Select user: ${PROJECT_NAME}-developer-test"
echo "     Add context key: aws:ResourceTag/Team = Dev"
echo "════════════════════════════════════════════════════════════════════"
