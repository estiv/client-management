# Client Management — design-time architecture

Users on the internet reach **alb**. The load balancer forwards to **client-management-api**. The client-management-api stores records in **client-db**.

This page is a design document. It describes the intended application. It does not describe a running account.

## Assets

| Name | What it is | Exposure |
|---|---|---|
| alb | Internet-facing application load balancer | internet |
| client-management-api | API workload | internal |
| client-db | Postgres database | internal |

## Connections

- alb → client-management-api
- client-management-api → client-db

The diagram is `docs/client-management.drawio`. Object ids are `user`, `alb`, `api`, and `db`. Arrows are `arrow-user-alb`, `arrow-alb-api`, and `arrow-api-db`.

## Configured controls

RDS encryption is configured with storage_encrypted = true on `aws_db_instance.client_db` in `infra/main.tf`.

A SAST job runs in CI on every push to main. The workflow is `.github/workflows/sast.yml`.

## Where each fact is written

| Fact | File |
|---|---|
| Internet-facing load balancer, API, encrypted database | `infra/main.tf` |
| Ingress, Service, Deployment | `k8s/client-management-api.yaml` |
| Boxes and arrows | `docs/client-management.drawio` |
| SAST job | `.github/workflows/sast.yml` |
