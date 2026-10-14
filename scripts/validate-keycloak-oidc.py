#!/usr/bin/env python3
"""Validate the local Keycloak platform-client role contract."""

import json
import re
import subprocess
from urllib.parse import urlparse


rendered = subprocess.check_output(
    ["helm", "template", "storemesh-keycloak", "storemesh-keycloak", "--set", "realm.enabled=true"],
    text=True,
)
match = re.search(r"storemesh-realm\.json: \|\n((?:  .*\n)*)", rendered)
if not match:
    raise SystemExit("realm ConfigMap was not rendered")

realm = json.loads("".join(line[2:] for line in match.group(1).splitlines(True)))
roles = {role["name"] for role in realm["roles"]["realm"]}
required_roles = {"admin", "operator", "observability-admin"}
missing_roles = required_roles - roles
if missing_roles:
    raise SystemExit(f"missing Keycloak realm roles: {sorted(missing_roles)}")

clients = {client["clientId"]: client for client in realm["clients"]}
tool_clients = {"grafana", "kiali", "kibana", "argocd"}
missing_clients = tool_clients - clients.keys()
if missing_clients:
    raise SystemExit(f"missing platform clients: {sorted(missing_clients)}")

for client_id in sorted(tool_clients):
    mappers = clients[client_id].get("protocolMappers", [])
    groups_mapper = next(
        (mapper for mapper in mappers if mapper.get("config", {}).get("claim.name") == "groups"),
        None,
    )
    if groups_mapper is None:
        raise SystemExit(f"{client_id} does not map realm roles to the groups claim")

expected_redirects = {
    "grafana": "http://localhost:3001/login/generic_oauth",
    "kiali": "https://localhost:20001/kiali",
    "kibana": "https://localhost:5601/api/security/oidc/callback",
    "argocd": "https://localhost:8443/auth/callback",
}
for client_id, redirect_uri in expected_redirects.items():
    redirects = clients[client_id].get("redirectUris", [])
    if redirect_uri not in redirects:
        raise SystemExit(f"{client_id} must register exact local redirect URI {redirect_uri}")
    if any("*" in candidate for candidate in redirects):
        raise SystemExit(f"{client_id} must not use wildcard redirect URIs")

custom_redirects = {
    client_id: f"https://{client_id}.example.test{urlparse(uri).path}"
    for client_id, uri in expected_redirects.items()
}
override_args = [
    "helm", "template", "storemesh-keycloak", "storemesh-keycloak",
    "--set", "realm.enabled=true",
]
for client_id, redirect_uri in custom_redirects.items():
    override_args.extend([
        "--set-json",
        f"realm.clients.{client_id}.redirectUris={json.dumps([redirect_uri])}",
    ])
custom_render = subprocess.check_output(override_args, text=True)
custom_match = re.search(r"storemesh-realm\.json: \|\n((?:  .*\n)*)", custom_render)
if not custom_match:
    raise SystemExit("custom realm ConfigMap was not rendered")
custom_realm = json.loads("".join(line[2:] for line in custom_match.group(1).splitlines(True)))
custom_clients = {client["clientId"]: client for client in custom_realm["clients"]}
for client_id, redirect_uri in custom_redirects.items():
    if custom_clients[client_id].get("redirectUris") != [redirect_uri]:
        raise SystemExit(f"{client_id} does not honor its environment callback override")

print("Keycloak platform role and callback contract is valid")
