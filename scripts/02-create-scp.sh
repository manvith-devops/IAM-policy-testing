#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# 02-create-scp.sh
# Assignment 18 - Create a Service Control Policy (SCP)
#
# What is an SCP?
#   A policy applied to an AWS Organizations Organizational Unit (OU).
#   It limits what ALL accounts in that OU can do — even root/admin users.
#   Think of it as guardrails for the entire AWS account.
#
# What this SCP does:
#   - Deny all AWS actions in any region except us-east-1 and eu-west-1
#   - Deny deletion or modification of CloudTrail
#   - Deny leaving the AWS Organization
#
# ⚠️  REQUIREMENT: AWS Organizations must be enabled in your account.
#     Free tier accounts usually do NOT have Organizations enabled.
#     If you get an error, skip this script and just review the JSON file.
# ─────────────────────────────────────────────────────────────────────────────

set -e

# ─── Config ───────────────────────────────────────────────────────────────────
SCP_NAME="assignment18-scp"
SCP_DESCRIPTION="Restrict regions to us-east-1 and eu-west-1. Protect CloudTrail."
SCP_FILE="../cloudformation/scp-policy.json"
REGION="us-east-1"

# ─── Step 1: Verify AWS Organizations is available ───────────────────────────
echo "🔍 Checking if AWS Organizations is enabled..."
ORG_CHECK=$(aws organizations describe-organization \
  --region "$REGION" \
  --query "Organization.Id" \
  --output text 2>/dev/null || echo "NOT_ENABLED")

if [ "$ORG_CHECK" == "NOT_ENABLED" ]; then
  echo ""
  echo "⚠️  AWS Organizations is NOT enabled in your account."
  echo ""
  echo "   For this training assignment, the SCP has been saved as JSON:"
  echo "   cloudformation/scp-policy.json"
  echo ""
  echo "   You can review the policy content there."
  echo "   To actually apply SCPs, you need an AWS Organization."
  echo ""
  echo "   The JSON was designed to:"
  echo "   ✅ Deny all regions except us-east-1 and eu-west-1"
  echo "   ✅ Deny CloudTrail deletion/modification"
  echo "   ✅ Deny leaving the Organization"
  echo ""
  echo "📚 Learn more: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html"
  exit 0
fi

echo "✅ AWS Organizations found: $ORG_CHECK"

# ─── Step 2: Check if SCP already exists ─────────────────────────────────────
echo ""
echo "🔍 Checking if SCP already exists..."
EXISTING_SCP=$(aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY \
  --region "$REGION" \
  --query "Policies[?Name=='$SCP_NAME'].Id" \
  --output text)

if [ -n "$EXISTING_SCP" ]; then
  echo "⚠️  SCP already exists with ID: $EXISTING_SCP"
  echo "   Skipping creation. Delete it first if you want to recreate."
  exit 0
fi

# ─── Step 3: Create the SCP ──────────────────────────────────────────────────
echo ""
echo "🚀 Creating Service Control Policy: $SCP_NAME"

SCP_ID=$(aws organizations create-policy \
  --name "$SCP_NAME" \
  --description "$SCP_DESCRIPTION" \
  --content "$(cat $SCP_FILE)" \
  --type SERVICE_CONTROL_POLICY \
  --region "$REGION" \
  --query "Policy.PolicySummary.Id" \
  --output text)

echo "✅ SCP created! ID: $SCP_ID"

# ─── Step 4: Show how to attach it ───────────────────────────────────────────
echo ""
echo "📋 Next step - Attach SCP to a Test OU:"
echo ""
echo "   1. Find your OU ID:"
echo "      aws organizations list-organizational-units-for-parent \\"
echo "        --parent-id \$(aws organizations list-roots --query 'Roots[0].Id' --output text) \\"
echo "        --query 'OrganizationalUnits[*].[Id,Name]' --output table"
echo ""
echo "   2. Attach SCP to the OU:"
echo "      aws organizations attach-policy \\"
echo "        --policy-id $SCP_ID \\"
echo "        --target-id <YOUR_OU_ID>"
echo ""
echo "⚠️  WARNING: Attaching this SCP will immediately restrict ALL accounts"
echo "   in that OU. Only attach to a test OU, never to production."
