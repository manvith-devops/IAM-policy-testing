# IAM Policy Validation Guide

This guide explains how to validate and test the IAM policies created in this assignment using the AWS Management Console.

---

## 1. Using the IAM Policy Simulator

The IAM Policy Simulator helps verify whether a user is allowed or denied specific actions without making actual changes in AWS.

### Steps

1. Open the IAM Policy Simulator:
   https://policysim.aws.amazon.com/

2. Under **Users**, select:
   `assignment18-developer-test`

3. In **Action Settings**, run the following tests.

### Amazon S3 Validation

| Service | Action | Expected Result |
|----------|----------|----------------|
| Amazon S3 | ListAllMyBuckets | ✅ Allowed |
| Amazon S3 | GetObject | ✅ Allowed |
| Amazon S3 | PutObject | 🚫 Denied |
| Amazon S3 | DeleteObject | 🚫 Denied |
| Amazon S3 | DeleteBucket | 🚫 Denied |

#### Testing Resource Tag Conditions

**Development Bucket**

- Click **Add Condition**
- Key: `aws:ResourceTag/Team`
- Value: `Dev`
- Test `GetObject`
- Expected Result: ✅ Allowed

**Production Bucket**

- Key: `aws:ResourceTag/Environment`
- Value: `production`
- Test `GetObject`
- Expected Result: 🚫 Denied

### Amazon EC2 Validation

| Action | Context Key | Value | Expected Result |
|----------|------------|---------|----------------|
| RunInstances | ec2:InstanceType | t2.micro | ✅ Allowed |
| RunInstances | ec2:InstanceType | t3.micro | ✅ Allowed |
| RunInstances | ec2:InstanceType | t2.large | 🚫 Denied |
| RunInstances | ec2:InstanceType | m5.xlarge | 🚫 Denied |
| DescribeInstances | N/A | N/A | ✅ Allowed |

#### Instance Type Testing

1. Click **Add Context Key**
2. Enter:
   - Key: `ec2:InstanceType`
   - Value: `t2.micro`
3. Verify access is allowed.
4. Change the value to `t2.large`.
5. Verify access is denied.

### IAM Permission Checks

| Action | Expected Result |
|----------|----------------|
| CreateUser | 🚫 Denied |
| CreateRole | 🚫 Denied |
| AttachUserPolicy | 🚫 Denied |

These restrictions are enforced through the permission boundary.

---

## 2. Reviewing the Permission Boundary

1. Navigate to **IAM → Users → assignment18-developer-test**
2. Open the **Permissions** tab.
3. Verify the following policies are attached:
   - `assignment18-developer-policy`
   - `assignment18-permission-boundary`
4. Open the boundary policy and review the explicit deny statements.

**Note:** The permission boundary acts as the maximum permission limit. Even if broader permissions are attached later, restricted IAM actions remain blocked.

---

## 3. AWS IAM Access Analyzer

1. Open:
   https://console.aws.amazon.com/access-analyzer

2. Select **Analyzers**
3. Verify that `assignment18-analyzer` is listed as **Active**
4. Review the **Findings** tab

A correctly configured environment should display no findings.

### Policy Validation

1. Select **Policy Validation**
2. Click **Validate Policy**
3. Paste the developer policy JSON
4. Review any recommendations or warnings returned by Access Analyzer

---
