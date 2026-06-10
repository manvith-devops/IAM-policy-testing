#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# 05-test-assume-role.sh
# Assignment 18 - Test Assume Role with Session Policies
#
# What is a Session Policy?
#   When you assume a role, you can pass an EXTRA policy that further
#   restricts what you can do during that session.
#   Think of it like borrowing a car (the role), but the car owner
#   puts a GPS restriction so you can only drive in certain areas (session policy).
#
#   Important: Session policy can ONLY restrict, never expand permissions.
#   It works as: (Role Permissions) AND (Session Policy) AND (Boundary)
#
# This script:
#   1. Uses the admin user (you) to simulate what developer-test can assume
#   2. Shows the role ARN and simulates a session with restricted permissions
#   3. Demonstrates the layered security model
#
# Note: To fully test assume-role, you'd need to create access keys for
# developer-test user and use those credentials. This script uses your
# current credentials to demonstrate the role + session policy concept.
# ─────────────────────────────────────────────────────────────────────────────

set -e

# ─── Config ───────────────────────────────────────────────────────────────────
REGION="us-east-1"
PROJECT_NAME="assignment18"
STACK_NAME="${PROJECT_NAME}-iam"

echo "🔐 Assume Role + Session Policy Testing"
echo "════════════════════════════════════════"
echo ""

# ─── Get the Role ARN from CFN ────────────────────────────────────────────────
echo "📌 Step 1: Getting role ARN from CloudFormation..."

ROLE_ARN=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='DeveloperRoleArn'].OutputValue" \
  --output text 2>/dev/null)

USER_ARN=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='DeveloperUserArn'].OutputValue" \
  --output text 2>/dev/null)

if [ -z "$ROLE_ARN" ]; then
  echo "   ❌ Could not find role ARN. Make sure 01-deploy-iam.sh ran first."
  exit 1
fi

echo "   ✅ Developer user : $USER_ARN"
echo "   ✅ Developer role  : $ROLE_ARN"

# ─── Show the Session Policy ──────────────────────────────────────────────────
echo ""
echo "📌 Step 2: Defining a session policy (extra restriction)..."
echo ""
echo "   The session policy below adds an EXTRA restriction on top of the role."
echo "   In this example, we restrict the session to S3 actions only."
echo "   Even though the role allows EC2, the session cannot use EC2."
echo ""

# Session policy: restrict to only S3 read during this session
SESSION_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SessionAllowS3ReadOnly",
      "Effect": "Allow",
      "Action": [
        "s3:ListAllMyBuckets",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": "*"
    }
  ]
}'

echo "   Session Policy:"
echo "$SESSION_POLICY" | python3 -m json.tool
echo ""

# ─── Simulate the Assume Role ─────────────────────────────────────────────────
echo "📌 Step 3: Simulating assume role with session policy..."
echo ""
echo "   The following command shows how developer-test would assume the role:"
echo "   (This uses YOUR current credentials to call STS)"
echo ""

# Try to assume the role (this will work since we're running as admin)
STS_RESULT=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name "session-policy-test" \
  --policy "$SESSION_POLICY" \
  --duration-seconds 900 \
  --region "$REGION" \
  --query "Credentials" \
  --output json 2>/dev/null || echo "FAILED")

if [ "$STS_RESULT" == "FAILED" ]; then
  echo "   ⚠️  Could not assume role with current credentials."
  echo "   (This is expected - your current user may not be the developer-test user.)"
  echo ""
  echo "   To test assume-role manually:"
  echo "   1. Create access keys for the developer-test user"
  echo "   2. Configure a new AWS CLI profile:"
  echo "      aws configure --profile developer-test"
  echo "   3. Then assume the role:"
  echo "      aws sts assume-role \\"
  echo "        --role-arn $ROLE_ARN \\"
  echo "        --role-session-name test-session \\"
  echo "        --policy '<paste session policy JSON>' \\"
  echo "        --profile developer-test"
else
  echo "   ✅ Role assumed successfully!"
  echo ""
  echo "   Temporary credentials retrieved (showing only key prefix for security):"
  ACCESS_KEY=$(echo "$STS_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKeyId'][:8] + '****')")
  EXPIRY=$(echo "$STS_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['Expiration'])")
  echo "   Access Key : $ACCESS_KEY"
  echo "   Expires    : $EXPIRY"
fi

# ─── Explain the layered security model ──────────────────────────────────────
echo ""
echo "📌 Step 4: Understanding the layered security model"
echo ""
echo "   ┌─────────────────────────────────────────────────────────┐"
echo "   │            Effective Permission Calculation             │"
echo "   │                                                         │"
echo "   │  Developer Policy (what user is allowed to do)         │"
echo "   │       AND                                               │"
echo "   │  Permission Boundary (max ceiling, never exceeded)     │"
echo "   │       AND                                               │"
echo "   │  Session Policy (extra restrictions for this session)  │"
echo "   │       =                                                 │"
echo "   │  What the user can ACTUALLY do in this session         │"
echo "   └─────────────────────────────────────────────────────────┘"
echo ""
echo "   Example: Even if the role allows EC2, if the session policy"
echo "   doesn't include EC2, the session cannot use EC2."
echo ""
echo "   This is useful for:"
echo "   - CI/CD pipelines (give just enough for the job)"
echo "   - Temporary elevated access (limit blast radius)"
echo "   - Audit trails (each session has a unique name)"
echo ""
echo "════════════════════════════════════════"
echo "  ✅ Session policy concept demonstrated!"
echo "════════════════════════════════════════"
