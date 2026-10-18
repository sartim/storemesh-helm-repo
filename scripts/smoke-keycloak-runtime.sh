#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
container_name="storemesh-keycloak-smoke-${GITHUB_RUN_ID:-local}-$$"
host_port="${KEYCLOAK_SMOKE_PORT:-18080}"
management_port="${KEYCLOAK_SMOKE_MANAGEMENT_PORT:-19000}"
base_url="http://127.0.0.1:${host_port}"
admin_password="$(openssl rand -hex 24)"
container_started=false

cleanup() {
  local status=$?
  if [[ "$status" -ne 0 && "$container_started" == true ]]; then
    docker logs "$container_name" >&2 || true
  fi
  docker rm --force "$container_name" >/dev/null 2>&1 || true
  rm -r "$work_dir"
  exit "$status"
}
trap cleanup EXIT

helm template storemesh-keycloak "$repo_root/storemesh-keycloak" \
  --set realm.enabled=true > "$work_dir/rendered.yaml"

image="$(ruby -ryaml -e '
docs = YAML.load_stream(File.read(ARGV.fetch(0)))
deployment = docs.find { |doc| doc.is_a?(Hash) && doc["kind"] == "Deployment" }
abort "Keycloak Deployment was not rendered" unless deployment
container = deployment.dig("spec", "template", "spec", "containers")&.find { |item| item["name"] == "keycloak" }
abort "Keycloak container was not rendered" unless container
expected_args = ["start-dev", "--http-port=8080", "--import-realm", "--health-enabled=true"]
abort "Keycloak development runtime args changed; update the runtime smoke" unless container["args"] == expected_args
ports = container["ports"].to_h { |port| [port["name"], port["containerPort"]] }
abort "management port 9000 is missing" unless ports["management"] == 9000
%w[startupProbe readinessProbe livenessProbe].each do |probe_name|
  probe = container[probe_name]
  abort "#{probe_name} is missing or not on management port" unless probe && probe.dig("httpGet", "port") == "management"
end
image = container.fetch("image")
abort "unexpected Keycloak image" unless image.start_with?("quay.io/keycloak/keycloak:")
puts image
' "$work_dir/rendered.yaml")"

ruby -ryaml -e '
docs = YAML.load_stream(File.read(ARGV.fetch(0)))
config_map = docs.find { |doc| doc.is_a?(Hash) && doc["kind"] == "ConfigMap" && doc.dig("data", "storemesh-realm.json") }
abort "Keycloak realm ConfigMap was not rendered" unless config_map
File.write(ARGV.fetch(1), config_map.dig("data", "storemesh-realm.json"))
' "$work_dir/rendered.yaml" "$work_dir/storemesh-realm.json"

mkdir "$work_dir/import"
mv "$work_dir/storemesh-realm.json" "$work_dir/import/storemesh-realm.json"

docker run --rm --detach \
  --name "$container_name" \
  --publish "127.0.0.1:${host_port}:8080" \
  --publish "127.0.0.1:${management_port}:9000" \
  --env KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  --env "KC_BOOTSTRAP_ADMIN_PASSWORD=${admin_password}" \
  --volume "$work_dir/import:/opt/keycloak/data/import:ro" \
  "$image" \
  start-dev --http-port=8080 --import-realm --health-enabled=true \
  "--hostname=${base_url}" >/dev/null
container_started=true

ready=false
for attempt in $(seq 1 90); do
  if curl --silent --fail "http://127.0.0.1:${management_port}/health/ready" >/dev/null; then
    ready=true
    break
  fi
  if [[ "$(docker inspect --format '{{.State.Running}}' "$container_name" 2>/dev/null || true)" != true ]]; then
    echo "Keycloak exited before readiness" >&2
    exit 1
  fi
  sleep 2
done

if [[ "$ready" != true ]]; then
  echo "Keycloak did not become ready within 180 seconds" >&2
  exit 1
fi

curl --silent --show-error --fail \
  "$base_url/realms/storemesh/.well-known/openid-configuration" \
  > "$work_dir/discovery.json"
ruby -rjson -e '
document = JSON.parse(File.read(ARGV.fetch(0)))
expected = ARGV.fetch(1) + "/realms/storemesh"
abort "OIDC discovery issuer mismatch" unless document["issuer"] == expected
%w[authorization_endpoint token_endpoint jwks_uri].each do |key|
  abort "OIDC discovery is missing #{key}" unless document[key].is_a?(String) && !document[key].empty?
end
puts "Keycloak runtime smoke passed: realm imported and OIDC discovery is healthy"
' "$work_dir/discovery.json" "$base_url"
