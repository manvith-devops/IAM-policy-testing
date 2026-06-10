#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# 04-test-access-analyzer.sh
# Assignment 18 - Run IAM Access Analyzer
#
# What IAM Access Analyzer does:
#   - Scans your AWS account for resources with EXTERNAL access
#   - Finds S3 buckets, IAM roles, KMS keys, etc. accessible from outside
#   - Also validates IAM policies for errors and security issues
#
# This script:
#   1. Creates an Access Analyzer for your account
#   2. Waits for findings to populate
#   3. Lists any findings (public/cross-account access)
#   4. Validates the developer policy for security issues
#
# Run AFTER 01-deploy-iam.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

# ─── Config ───────────────────────────────────────────────────────────────────
REGION="us-east-1"
PROJECT_NAME="assignment18"
ANALYZER_NAME="${PROJECT_NAME}-analyzer"
STACK_NAME="${PROJECT_NAME}-iam"

echo "🔍 IAM Access Analyzer - Assignment 18"
echo "════════════════════════════════════════"
echo ""

# ─── Step 1: Create or reuse the Access Analyzer ─────────────────────────────
echo "📌 Step 1: Setting up Access Analyzer..."

# Check if one already exists
EXISTING_ARN=$(aws accessanalyzer list-analyzers \
  --region "$REGION" \
  --query "analyzers[?name=='$ANALYZER_NAME'].arn" \
  --output text)

if [ -n "$EXISTING_ARN" ]; then
  echo "   ✅ Reusing existing analyzer: $EXISTING_ARN"
  ANALYZER_ARN="$EXISTING_ARN"
else
  echo "   🚀 Creating new analyzer: $ANALYZER_NAME"
  ANALYZER_ARN=$(aws accessanalyzer create-analyzer \
    --analyzer-name "$ANALYZER_NAME" \
    --type ACCOUNT \
    --region "$REGION" \
    --tags Project="$PROJECT_NAME" \
    --query "arn" \
    --output text)
  echo "   ✅ Analyzer created: $ANALYZER_ARN"

  echo ""
  echo "   ⏳ Waiting 15 seconds for initial scan to complete..."
  sleep 15
fi

# ─── Step 2: List findings ────────────────────────────────────────────────────
echo ""
echo "📌 Step 2: Checking for public/cross-account access findings..."

FINDING_COUNT=$(aws accessanalyzer list-findings \
  --analyzer-arn "$ANALYZER_ARN" \
  --region "$REGION" \
  --query "length(findings)" \
  --output text)

if [ "$FINDING_COUNT" == "0" ] || [ -z "$FINDING_COUNT" ]; then
  echo "   ✅ No public or cross-account access findings. Your resources look clean!"
else
  echo "   ⚠️  Found $FINDING_COUNT finding(s) — review below:"
  echo ""
  aws accessanalyzer list-findings \
    --analyzer-arn "$ANALYZER_ARN" \
    --region "$REGION" \
    --query "findings[*].{ID:id,Type:resourceType,Status:status,Public:isPublic}" \
    --output table
  echo ""
  echo "   📋 For details, open the console:"
  echo "   https://console.aws.amazon.com/access-analyzer"
fi

# ─── Step 3: Validate the Developer Policy ───────────────────────────────────
echo ""
echo "📌 Step 3: Validating the developer policy for security issues..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='DeveloperPolicyArn'].OutputValue" \
  --output text 2>/dev/null)

if [ -z "$POLICY_ARN" ]; then
  echo "   ❌ Could not find policy ARN. Make sure 01-deploy-iam.sh ran first."
else
  echo "   Policy ARN: $POLICY_ARN"
  echo ""

  # Get the policy document and validate it
  POLICY_JSON=$(aws iam get-policy-version \
    --policy-arn "$POLICY_ARN" \
    --version-id "v1" \
    --query "PolicyVersion.Document" \
    --output json)

  # Run policy validation via Access Analyzer
  VALIDATION=$(aws accessanalyzer validate-policy \
    --policy-document "$POLICY_JSON" \
    --policy-type IDENTITY_POLICY \
    --region "$REGION" \
    --query "findings[*].{Type:findingType,Issue:issueCode,Detail:learnMoreLink}" \
    --output table 2>/dev/null)

  if [ -z "$VALIDATION" ]; then
    echo "   ✅ Policy passed validation! No security issues found."
  else
    echo "   ⚠️  Policy validation findings:"
    echo "$VALIDATION"
    echo ""
    echo "   Review findings in the console:"
    echo "   https://console.aws.amazon.com/access-analyzer/home#/policy-validation"
  fi
fi

# ─── Step 4: Check Permission Boundary ───────────────────────────────────────
echo ""
echo "📌 Step 4: Validating the permission boundary..."

BOUNDARY_ARN=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='PermissionBoundaryArn'].OutputValue" \
  --output text 2>/dev/null)

if [ -n "$BOUNDARY_ARN" ]; then
  BOUNDARY_JSON=$(aws iam get-policy-version \
    --policy-arn "$BOUNDARY_ARN" \
    --version-id "v1" \
    --query "PolicyVersion.Document" \
    --output json)

  BOUNDARY_VALIDATION=$(aws accessanalyzer validate-policy \
    --policy-document "$BOUNDARY_JSON" \
    --policy-type IDENTITY_POLICY \
    --region "$REGION" \
    --query "findings[*].findingType" \
    --output text 2>/dev/null)

  if [ -z "$BOUNDARY_VALIDATION" ]; then
    echo "   ✅ Permission boundary passed validation!"
  else
    echo "   ⚠️  Boundary validation findings: $BOUNDARY_VALIDATION"
  fi
fi

echo ""
echo "════════════════════════════════════════"
echo "  ✅ Access Analyzer check complete!"
echo ""
echo "  📋 Console: https://console.aws.amazon.com/access-analyzer"
echo "════════════════════════════════════════"
