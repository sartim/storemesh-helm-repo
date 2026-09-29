#!/usr/bin/env python3
"""Validate the local Keycloak platform-client role contract."""

import json
import re
import subprocess


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

print("Keycloak platform role contract is valid")
