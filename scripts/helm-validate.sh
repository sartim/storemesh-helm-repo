#!/bin/sh

set -eu

repository_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
chart="$repository_root/storemesh-user-service"
rendered="$(mktemp)"

cleanup() {
    rm -f "$rendered"
}

trap cleanup EXIT INT TERM

command -v helm >/dev/null 2>&1 || {
    echo "helm is required for chart validation" >&2
    exit 1
}

helm lint --strict "$chart"
helm template storemesh-user-service "$chart" \
    --namespace storemesh-user-service >"$rendered"

order_chart="$repository_root/storemesh-order-service"
order_rendered="$(mktemp)"
trap 'rm -f "$rendered" "$order_rendered"' EXIT INT TERM
helm lint --strict "$order_chart"
helm template storemesh-order-service "$order_chart" \
    --namespace storemesh-order-service >"$order_rendered"

if grep -q 'storemesh-order-service-outbox-publisher' "$order_rendered"; then
    echo "Kafka outbox publisher must be disabled by default" >&2
    exit 1
fi

helm template storemesh-order-service "$order_chart" \
    --namespace storemesh-order-service \
    --set kafka.enabled=true \
    --set kafka.brokers=broker.example:9092 >/dev/null

if grep -Eq 'image: .*:(latest|main)$' "$rendered"; then
    echo "default chart values must use an immutable runtime image tag" >&2
    exit 1
fi

if grep -Eq '^kind: Secret$' "$rendered"; then
    echo "default chart values must reference an existing Secret" >&2
    exit 1
fi

echo "Helm chart linting and rendering validation passed"
