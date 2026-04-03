# Linux Server on AWS — Terraform + GitHub Actions

Deploys a hardened Amazon Linux 2023 EC2 instance to AWS using Terraform,
with GitHub Actions as the CI/CD pipeline authenticated via OIDC (no long-lived keys).

---

## Prerequisites

- AWS account with permissions to create EC2, IAM, and S3 resources
- Terraform >= 1.5 (for local runs)
- An S3 bucket for remote state storage

---

## One-Time AWS Setup

### 1. Create the S3 state bucket

```bash
aws s3api create-bucket \
  --bucket YOUR_TFSTATE_BUCKET \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket YOUR_TFSTATE_BUCKET \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket YOUR_TFSTATE_BUCKET \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

### 2. Create the OIDC provider for GitHub Actions

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 3. Create the IAM role for GitHub Actions

Create a file `trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

Then create the role and attach a policy:

```bash
aws iam create-role \
  --role-name github-actions-terraform \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name github-actions-terraform \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess  # Tighten for production
```

---

## GitHub Repository Setup

### Add the required secret

In your GitHub repo → **Settings → Secrets and variables → Actions**, add:

| Secret name    | Value                                                                  |
|----------------|------------------------------------------------------------------------|
| `AWS_ROLE_ARN` | `arn:aws:iam::YOUR_ACCOUNT_ID:role/github-actions-terraform`          |

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline
└── terraform/
    ├── main.tf                 # EC2, SG, EIP, AMI lookup
    ├── variables.tf            # All input variables
    ├── outputs.tf              # Instance IP, DNS, etc.
    └── terraform.tfvars.example
```

---

## Configure Your Deployment

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

Key values to update in `main.tf`:
- `bucket = "YOUR_TFSTATE_BUCKET"` in the `backend "s3"` block

---

## How the Pipeline Works

| Trigger                        | Action                        |
|-------------------------------|-------------------------------|
| Pull Request to `main`        | `terraform plan` + PR comment |
| Push / merge to `main`        | `terraform apply`             |
| Manual dispatch → `plan`      | Plan only                     |
| Manual dispatch → `apply`     | Apply                         |
| Manual dispatch → `destroy`   | Destroy all resources         |

---

## Local Development

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

---

## Security Notes

- **Restrict SSH**: Change `allowed_ssh_cidr` to your IP (`["YOUR.IP.ADDRESS/32"]`)
- **Tighten IAM**: Replace `PowerUserAccess` with a least-privilege policy for production
- **State bucket**: Keep your S3 bucket private and enable versioning (done above)
- **SSH key**: Set `public_key_path` to your public key to enable SSH access
