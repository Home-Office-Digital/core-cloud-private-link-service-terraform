# Terraform Module Testing

This repository includes native Terraform tests for each module under module-local `tests` folders.

## Test Layout

- `modules/endpoint-service/tests/endpoint-service.tftest.hcl`
- `modules/endpoint-service-with-multi-targets/tests/endpoint-service-with-multi-targets.tftest.hcl`

Each test file includes:

- Multiple valid `plan` runs that verify outputs for single-service and multi-service inputs.
- Validation-failure runs that confirm constraints are enforced (for example target IP count checks).
- Additional negative runs that exercise invalid service maps (including mixed valid/invalid entries).
- `mock_provider "aws" {}` so tests do not call live AWS APIs.
- Placeholder-only values (for example `000000000000`, `vpc-000...`, `subnet-000...`) and reserved documentation IP ranges (`192.0.2.0/24`, `198.51.100.0/24`) to avoid real test data.

## Prerequisites

- Terraform CLI `>= 1.7` (for `terraform test` and provider mocking support).
- Internet access once to download Terraform providers.

## Run Tests Locally

Run tests module-by-module from the repository root.

```bash
terraform -chdir=modules/endpoint-service init -backend=false
terraform -chdir=modules/endpoint-service test

terraform -chdir=modules/endpoint-service-with-multi-targets init -backend=false
terraform -chdir=modules/endpoint-service-with-multi-targets test
```

## Optional: Run Both Modules in One Script

```bash
for module in modules/endpoint-service modules/endpoint-service-with-multi-targets; do
  terraform -chdir="$module" init -backend=false
  terraform -chdir="$module" test
done
```