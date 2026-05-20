# OPA Gatekeeper Policies

Policies are maintained as a **single source of truth** in `conftest/policies/*.rego` and automatically transformed into Gatekeeper-compatible resources.

## Architecture

```
conftest/policies/*.rego          ← Source of truth (Conftest format)
         │
         │  task generate:gatekeeper
         │  (Python: conftest/generate-gatekeeper.py)
         ▼
k3s/policies/templates/*.yaml     ← ConstraintTemplate CRDs (Gatekeeper format)
k3s/policies/constraints/*.yaml   ← Constraint CRDs (Gatekeeper format)
```

### Conftest vs Gatekeeper Rego differences

| Feature | Conftest | Gatekeeper |
|---|---|---|
| Input path | `input.spec.*` | `input.review.object.spec.*` |
| Violation rule | `deny contains msg if { ... }` | `violation[{"msg": msg}] { ... }` |
| Packaging | `package main` | Wrapped in ConstraintTemplate CRD |

### Rego file metadata

Each conftest Rego file requires two header comments for generation:

```rego
package main

# gatekeeper-kind: NoRunAsRoot
# gatekeeper-name: norunasroot

deny contains msg if { ... }
```

- `gatekeeper-kind`: CamelCase name for the Gatekeeper CRD kind
- `gatekeeper-name`: lowercase name for the ConstraintTemplate metadata

## Commands

### Generate Gatekeeper policies

```bash
task generate:gatekeeper
```

This reads all `conftest/policies/*.rego`, transforms them, and writes:
- `k3s/policies/templates/*.yaml`
- `k3s/policies/constraints/*.yaml`

### Run conftest locally

```bash
conftest test -p conftest/policies $(find k3s -name '*.yaml' -not -path '*/policies/*')
```

### Apply policies to cluster

```bash
# Templates first, then constraints:
kubectl apply -f k3s/policies/templates/
kubectl apply -f k3s/policies/constraints/
```

Or just use the deploy task which handles everything:

```bash
task apply
```

## CI

- **PRs**: conftest validates manifests + generated files are up to date
- **Push to main**: generates Gatekeeper policies and deploys them

Gatekeeper must be installed on the cluster first:

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.15/deploy/gatekeeper.yaml
```