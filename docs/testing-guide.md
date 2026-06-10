# Assignment 18 - IAM Policy Testing Guide

This guide walks you through testing all the policies in the AWS Console.  
Run the scripts first, then follow these steps to verify everything visually.

---

## 1. Policy Simulator (Console)

The Policy Simulator lets you test what an IAM user can or cannot do — without actually doing it.

**Steps:**
1. Open: https://policysim.aws.amazon.com/
2. In the left panel under **Users**, select: `assignment18-developer-test`
3. In the **Action Settings** area, test the following:

### S3 Tests

| Service | Action | Expected Result |
|---------|--------|-----------------|
| Amazon S3 | ListAllMyBuckets | ✅ Allowed |
| Amazon S3 | GetObject | ✅ Allowed |
| Amazon S3 | DeleteObject | 🚫 Denied |
| Amazon S3 | DeleteBucket | 🚫 Denied |
| Amazon S3 | PutObject | 🚫 Denied |

**Test with tag condition (Dev bucket):**
- Click **"Add condition"**
- Key: `aws:ResourceTag/Team` → Value: `Dev`
- Test `GetObject` → should be ✅ Allowed

**Test with tag condition (Production bucket):**
- Key: `aws:ResourceTag/Environment` → Value: `production`
- Test `GetObject` → should be 🚫 Denied (production block)

### EC2 Tests

| Action | Context Key | Value | Expected |
|--------|-------------|-------|----------|
| RunInstances | ec2:InstanceType | t2.micro | ✅ Allowed |
| RunInstances | ec2:InstanceType | t3.micro | ✅ Allowed |
| RunInstances | ec2:InstanceType | t2.large | 🚫 Denied |
| RunInstances | ec2:InstanceType | m5.xlarge | 🚫 Denied |
| DescribeInstances | (none) | | ✅ Allowed |

**Add instance type context:**
- In the simulator, click **"Add context key"**
- Key: `ec2:InstanceType`, Value: `t2.micro` → Allowed ✅
- Change value to `t2.large` → Denied 🚫

### IAM Tests (Boundary enforcement)

| Action | Expected |
|--------|----------|
| CreateUser | 🚫 Denied (boundary blocks IAM) |
| CreateRole | 🚫 Denied (boundary blocks IAM) |
| AttachUserPolicy | 🚫 Denied (boundary blocks IAM) |

---

## 2. Permission Boundary Verification

1. Go to: **IAM Console → Users → assignment18-developer-test**
2. Click the **Permissions** tab
3. You should see:
   - Policy: `assignment18-developer-policy` (the restrictions)
   - Boundary: `assignment18-permission-boundary` (the ceiling)
4. Click on the boundary — review the Deny statements for IAM and production resources

**Key concept:** Even if someone attaches `AdministratorAccess` to this user, they still cannot perform IAM actions because the boundary explicitly denies them.

---

## 3. IAM Access Analyzer (Console)

1. Go to: https://console.aws.amazon.com/access-analyzer
2. In the left menu, click **Analyzers**
3. You should see: `assignment18-analyzer` — Status: Active
4. Click on it → Review the **Findings** tab
5. A clean environment shows **0 findings**

**Policy Validation:**
1. In Access Analyzer, click **Policy validation** in the left menu
2. Click **Validate policy**
3. Paste the developer policy JSON and click **Validate**
4. Review any security warnings or suggestions

---

## 4. Assume Role with Session Policy (Console)

**Visual way to understand session policies:**

1. Go to: **IAM Console → Roles → assignment18-developer-role**
2. Click the **Trust relationships** tab
3. You'll see only `assignment18-developer-test` user is trusted to assume this role
4. The role itself also has the permission boundary attached

**What a session policy does:**
```
Effective permissions = Role Policy ∩ Session Policy ∩ Boundary

Even if the role allows S3 + EC2,
a session policy limiting to S3 only means:
the session can ONLY use S3.
```

---

## 5. Verify the VPC Restriction

The developer policy restricts EC2 launches to a specific VPC.

**Simulate it:**
1. Open Policy Simulator
2. Select the developer-test user
3. Action: `ec2:RunInstances`
4. Add context key: `ec2:Vpc` → `arn:aws:ec2:us-east-1:<account-id>:vpc/<your-vpc-id>`
5. Should be ✅ Allowed

6. Change `ec2:Vpc` to a different VPC ID
7. Should be 🚫 Denied

---

## 6. SCP Verification (if Organizations is enabled)

**If you created the SCP:**
1. Go to: **AWS Organizations Console → Policies → Service Control Policies**
2. Find: `assignment18-scp`
3. Review the two statements:
   - `DenyUnapprovedRegions`: Blocks all regions except us-east-1 and eu-west-1
   - `DenyCloudTrailDeletion`: Prevents CloudTrail from being deleted or stopped

**Test the SCP effect:**
- Switch to an account inside the target OU
- Try: `aws cloudtrail delete-trail --name <trail-name> --region us-east-1`
- Should get: `An error occurred (AccessDenied)...`

---

## Summary: IAM Policy Layers Explained

```
┌────────────────────────────────────────────────────────────────────┐
│                     AWS IAM Security Layers                        │
│                                                                    │
│  Layer 1: SCP (Organization-level)                                 │
│    → Applies to ALL users in the account/OU                        │
│    → Even root cannot bypass this                                  │
│                                                                    │
│  Layer 2: Permission Boundary (User-level ceiling)                 │
│    → User can never exceed this                                    │
│    → Even if admin policy is attached                              │
│                                                                    │
│  Layer 3: Identity Policy (What the user can do)                  │
│    → The day-to-day permissions                                    │
│    → Must be within the boundary                                   │
│                                                                    │
│  Layer 4: Session Policy (Per-session restriction)                │
│    → Only applies when assuming a role                             │
│    → Can ONLY reduce permissions, never add                        │
│                                                                    │
│  Effective access = SCP ∩ Boundary ∩ Policy ∩ Session Policy      │
└────────────────────────────────────────────────────────────────────┘
```

---

## Screenshots to Take

Save in the `screenshots/` folder:

- [ ] Policy Simulator showing S3 ListAllMyBuckets = Allowed
- [ ] Policy Simulator showing S3 DeleteObject = Denied
- [ ] Policy Simulator showing EC2 RunInstances t2.micro = Allowed
- [ ] Policy Simulator showing EC2 RunInstances t2.large = Denied
- [ ] IAM User → Permissions tab showing boundary attached
- [ ] Access Analyzer → Findings (0 findings = clean)
- [ ] Access Analyzer → Policy validation result
- [ ] IAM Role → Trust relationships tab
