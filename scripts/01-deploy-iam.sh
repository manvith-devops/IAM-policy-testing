#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# 01-deploy-iam.sh
# Assignment 18 - Deploy IAM User, Policies, and Permission Boundary
#
# What this does:
#   1. Finds your default VPC (or use a custom one)
#   2. Deploys the CloudFormation stack with the IAM user + policies
#   3. Shows the stack outputs when done
#
# Usage:
#   ./01-deploy-iam.sh
#   VPC_ID=vpc-xxxxxxxx ./01-deploy-iam.sh   # Use a specific VPC
# ─────────────────────────────────────────────────────────────────────────────

set -e  # Exit immediately if any command fails

# ─── Config (change these if needed) ─────────────────────────────────────────
STACK_NAME="assignment18-iam"
REGION="us-east-1"
PROJECT_NAME="assignment18"
TEMPLATE_PATH="../cloudformation/iam-user-policy.yaml"

# ─── Step 1: Find VPC ─────────────────────────────────────────────────────────
# Use VPC_ID env variable if set, otherwise find the default VPC
if [ -n "$VPC_ID" ]; then
  echo "✅ Using VPC from environment variable: $VPC_ID"
  DEV_VPC_ID="$VPC_ID"
else
  echo "🔍 Looking up default VPC in $REGION..."
  DEV_VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region "$REGION")

  # Check if we got a valid VPC
  if [ "$DEV_VPC_ID" == "None" ] || [ -z "$DEV_VPC_ID" ]; then
    echo ""
    echo "❌ ERROR: No default VPC found in $REGION."
    echo "   Please provide your VPC ID manually:"
    echo "   VPC_ID=vpc-xxxxxxxx ./01-deploy-iam.sh"
    exit 1
  fi

  echo "✅ Found default VPC: $DEV_VPC_ID"
fi

# ─── Step 2: Confirm before deploying ────────────────────────────────────────
echo ""
echo "📋 About to deploy:"
echo "   Stack Name : $STACK_NAME"
echo "   Region     : $REGION"
echo "   Project    : $PROJECT_NAME"
echo "   Dev VPC    : $DEV_VPC_ID"
echo ""
read -p "Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Cancelled."
  exit 0
fi

# ─── Step 3: Deploy CloudFormation ───────────────────────────────────────────
echo ""
echo "🚀 Deploying CloudFormation stack..."
echo "   This creates the IAM user, policy, permission boundary, and role."
echo ""

aws cloudformation deploy \
  --template-file "$TEMPLATE_PATH" \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    ProjectName="$PROJECT_NAME" \
    DevVpcId="$DEV_VPC_ID" \
    AllowedRegion="$REGION"

echo ""
echo "✅ Stack deployed successfully!"

# ─── Step 4: Show what was created ───────────────────────────────────────────
echo ""
echo "📋 Resources created:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[*].[OutputKey, OutputValue]" \
  --output table

echo ""
echo "🎉 Done! Next step: run 03-test-policy-simulator.sh to test permissions."
