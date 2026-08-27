# StoreMesh Helm repository

This repository contains the deployable StoreMesh Helm charts.

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
logic. Manual runs against private images require the read-only repository
secret `GHCR_READ_TOKEN`; a calling image repository can use its own workflow
token instead.
