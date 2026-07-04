# tf-infrastructure

Terraform infrastructure managed across multiple AWS accounts.

## Local Development Setup

### 1. Install tenv

[tenv](https://github.com/tofuutils/tenv) is the recommended tool for managing Terraform versions locally. Download the latest release binary from the [GitHub releases page](https://github.com/tofuutils/tenv/releases) and place it in your `PATH`.

Once installed, tenv will automatically pick up the required Terraform version from each module's `required_version` constraint when you run `terraform` commands inside that directory.

### 2. AWS Profile Configuration

This repo manages resources across two AWS accounts. Add the following SSO profiles to your `~/.aws/config`:

```ini
[profile fede-dev]
sso_session = fede-dev
sso_account_id = 271223117946
sso_role_name = AWSAdministratorAccess
region = eu-north-1

[profile infrastructure]
sso_session = fede-dev
sso_account_id = 233231935067
sso_role_name = AWSAdministratorAccess
region = eu-north-1

[profile loissutela]
sso_session = fede-dev
sso_account_id = 592404496683
sso_role_name = AWSAdministratorAccess
region = eu-north-1

[sso-session fede-dev]
sso_start_url = https://fede-dev.awsapps.com/start/
sso_region = eu-north-1
sso_registration_scopes = sso:account:access
```

Then log in before running any Terraform commands:

```bash
aws sso login --sso-session fede-dev
```

Profile usage per account:

| Account directory          | AWS profile used (provider) | AWS profile used (backend) |
|----------------------------|-----------------------------|----------------------------|
| `accounts/fede-dev/`       | `fede-dev`                  | `fede-dev`                 |
| `accounts/infrastructure/` | `infrastructure`            | `fede-dev`                 |
| `accounts/loissutela/`     | `loissutela`                | `fede-dev`                 |


### 3. Initialize and apply

From any module directory:

```bash
terraform init
terraform plan
terraform apply
```
