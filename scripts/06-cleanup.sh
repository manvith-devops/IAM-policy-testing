#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# 06-cleanup.sh
# Assignment 18 - Remove all created resources
#
# What gets deleted:
#   - IAM user (assignment18-developer-test)
#   - IAM policies (developer policy + permission boundary)
#   - IAM role (developer assume role)
#   - IAM Access Analyzer
#   - The CloudFormation stack itself
#
# What is NOT deleted:
#   - The SCP (if you created one — delete manually from Organizations console)
# ─────────────────────────────────────────────────────────────────────────────

set -e

STACK_NAME="assignment18-iam"
REGION="us-east-1"
PROJECT_NAME="assignment18"
ANALYZER_NAME="${PROJECT_NAME}-analyzer"

echo "🗑️  Cleanup - Assignment 18: IAM Policy Testing"
echo "══════════════════════════════════════════════"
echo ""
echo "  This will delete:"
echo "  - IAM user: ${PROJECT_NAME}-developer-test"
echo "  - IAM policies: ${PROJECT_NAME}-developer-policy"
echo "  - IAM permission boundary: ${PROJECT_NAME}-permission-boundary"
echo "  - IAM role: ${PROJECT_NAME}-developer-role"
echo "  - Access Analyzer: ${ANALYZER_NAME}"
echo "  - CloudFormation stack: $STACK_NAME"
echo ""
read -p "Are you sure you want to delete everything? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cleanup cancelled. No resources were deleted."
  exit 0
fi

echo ""

# ─── Delete Access Analyzer ──────────────────────────────────────────────────
echo "🔍 Removing Access Analyzer..."

ANALYZER_EXISTS=$(aws accessanalyzer list-analyzers \
  --region "$REGION" \
  --query "analyzers[?name=='$ANALYZER_NAME'].arn" \
  --output text 2>/dev/null)

if [ -n "$ANALYZER_EXISTS" ]; then
  aws accessanalyzer delete-analyzer \
    --analyzer-name "$ANALYZER_NAME" \
    --region "$REGION"
  echo "   ✅ Access Analyzer deleted"
else
  echo "   ℹ️  No analyzer found, skipping"
fi

# ─── Delete CloudFormation Stack ─────────────────────────────────────────────
echo ""
echo "🏗️  Deleting CloudFormation stack: $STACK_NAME..."
echo "   (This removes the IAM user, policies, and role)"

STACK_EXISTS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].StackStatus" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_EXISTS" == "NOT_FOUND" ]; then
  echo "   ℹ️  Stack not found, skipping"
else
  aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

  echo "   ⏳ Waiting for stack to finish deleting..."
  aws cloudformation wait stack-delete-complete \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

  echo "   ✅ Stack deleted"
fi

echo ""
echo "══════════════════════════════════════════════"
echo "  🎉 Cleanup complete! All Assignment 18"
echo "     resources have been removed."
echo ""
echo "  ⚠️  If you created an SCP, delete it manually:"
echo "     AWS Console → Organizations → Policies → SCPs"
echo "══════════════════════════════════════════════"
