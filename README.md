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
