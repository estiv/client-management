# sample-repo

Sample client repository for **Scope 1** design-time architecture ingestion.

This folder is the **Client Management** application as design-time source material: a diagram, Terraform, Kubernetes manifests, a CI workflow, and docs. Cronus is not part of this repository. Scope 1 watches these files through a GitHub push webhook. The worker later reads them with a read-only token stored in AWS Secrets Manager.

Current phase is design-time only. These files are configured intent. They are not a live AWS, Kubernetes, or CMDB inventory.

## Demo identity

Operators set these on the job. Source files are untrusted input and do not assign tenant, application, or plane.

| Field | Value |
|---|---|
| Tenant ID | `acme` |
| Application ID | `client-management` |
| Repository name | `client-management` |
| Default branch | `main` |

When you push this folder to GitHub, use a repository named `client-management` under your GitHub owner (for example `your-org/client-management`). The Scope 1 mapping row uses `{tenantId}#{owner}/client-management`.

## Contents

```text
sample-repo/
  infra/main.tf                      # ALB, API service, encrypted Postgres
  k8s/client-management-api.yaml     # Ingress, Service, Deployment
  docs/client-management.drawio      # Diagram with object ids and arrows
  docs/architecture.md               # Design notes
  .github/workflows/sast.yml         # Configured SAST job
  README.md
```

## What a design-time run should produce

Plane `design_time`. Control status `configured`.

| Kind | Name | Evidence |
|---|---|---|
| Asset | alb | `aws_lb.alb` (`internal = false`, `0.0.0.0/0` ingress, public subnets); diagram object `alb`; Internet / User arrow `arrow-user-alb` |
| Asset | client-management-api | `aws_ecs_service.client_management_api`; Deployment `client-management-api`; diagram object `api` |
| Asset | client-db | `aws_db_instance.client_db`; diagram object `db` |
| Connection | alb → client-management-api | listener forwards to `aws_lb_target_group.client_api`; arrow `arrow-alb-api`; Ingress to Service |
| Connection | client-management-api → client-db | task `DATABASE_HOST` references `aws_db_instance.client_db`; arrow `arrow-api-db` |
| Control | Encryption at rest | `storage_encrypted = true` on `aws_db_instance.client_db` |
| Control | SAST | job `sast` in `.github/workflows/sast.yml` |

Exposure for alb is `internet`. The API and database are `internal`.

Diagram labels and Terraform comments are client-written. Scope 1 may read them as evidence text. It takes `tenant_id`, `application_id`, `plane`, and `run_id` from the job, and it saves a row only when the citation exists in the file at the cited commit.

## Important

- Do **not** store GitHub personal access tokens, webhook secrets, or database passwords in this repository. `db_password` is a Terraform variable with no default.
- The webhook carries metadata only (event type, repository, commit, changed file paths).
- The ingestion service downloads nothing from this repo. The worker does that with a read-only credential.
