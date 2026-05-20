# OPA Gatekeeper Policies

Apply in order:
1. Constraints templates first: `kubectl apply -f templates/`
2. Then constraints: `kubectl apply -f constraints/`

Gatekeeper must be installed on the cluster first:
```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.15/deploy/gatekeeper.yaml
```