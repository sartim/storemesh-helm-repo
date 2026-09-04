# StoreMesh Helm repository

This repository contains the deployable StoreMesh Helm charts.

## Keycloak identity provider

`storemesh-keycloak` is the local OIDC foundation for the authentication
refactor. It uses the official Keycloak image in `start-dev` mode and is
intended for the Kind development cluster only. The default admin password is
development-only and must be overridden through `admin.existingSecret` before
any shared environment deployment.

The chart provides the Keycloak runtime and service boundary, imports the local
realm, and registers StoreMesh client applications. The web, Android, and iOS
clients include an explicit `storemesh-bff` access-token audience mapper so the
BFF and downstream services can enforce audience validation consistently.

## Manual deployment

The `Deploy Helm chart` GitHub Actions workflow is manually triggered with an
environment, chart, namespace, and immutable image tag. Configure these
environment-scoped settings before use:

- Variable `KUBE_CONTEXT`: the context name in the supplied kubeconfig.
- Secret `KUBE_CONFIG_B64`: base64-encoded kubeconfig for the target cluster.
- Production Environment: require reviewer approval.

The workflow validates the chart, selects the configured Kubernetes context,
runs `helm upgrade --install --wait`, and verifies the resulting Deployment.
It does not require Argo CD and does not use a floating image tag.

For deployments without a remote cluster, use the `Temporary Kind smoke
deployment` workflow. It creates an ephemeral Kind cluster inside the GitHub
runner, pulls the selected private GHCR image using the workflow token, loads
it into Kind, deploys the BFF or frontend chart, verifies readiness, and then
the runner is discarded. This is a smoke test environment, not persistent
staging or production. The workflow supports both manual dispatch and
`workflow_call`, so image-producing repositories can call this centralized
deployment check after publishing an image without duplicating Helm or Kind
logic. The generic frontend smoke deployment disables its optional Istio
resources because the ephemeral cluster does not install Istio CRDs; Istio
routing is verified in the local staging cluster separately. Manual runs against private images require the read-only repository
secret `GHCR_READ_TOKEN`; a calling image repository can use its own workflow
token instead.

## Kafka eventing

`storemesh-kafka` contains Confluent for Kubernetes resources for a local KRaft
cluster and initial StoreMesh topics. It is disabled by default, has no Argo CD
Application, and is not installed by the normal local bootstrap. The Order
Service also keeps its outbox publisher disabled by default. Enabling that
publisher only starts a worker against an externally supplied Kafka endpoint;
it does not install Kafka or Confluent for Kubernetes. PostgreSQL and gRPC
remain the transactional request path, and pending outbox records preserve
events while Kafka is unavailable.
