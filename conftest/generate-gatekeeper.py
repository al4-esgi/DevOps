#!/usr/bin/env python3
"""
Transform conftest Rego policies into Gatekeeper-compatible ConstraintTemplates + Constraints.

Single source of truth: conftest/policies/*.rego

Each .rego file must have these header comments:
    # gatekeeper-kind: <CamelCaseKind>
    # gatekeeper-name: <lowercasename>

Files without these headers (like lib.rego) are skipped.

Transformations applied to Rego:
    - deny contains msg if { ... }  →  violation[{"msg": msg}] { ... }
    - input.spec.*                  →  input.review.object.spec.*
    - containers[_]                 →  input.review.object.spec.template.spec.containers[_]
    - init_containers[_]            →  input.review.object.spec.template.spec.initContainers[_]
    - volumes[_]                    →  input.review.object.spec.template.spec.volumes[_]
    - pod_spec[_]                   →  input.review.object.spec.template.spec

Outputs:
    - k3s/policies/templates/<name>.yaml   (ConstraintTemplate CRDs)
    - k3s/policies/constraints/<name>.yaml  (Constraint CRDs)
"""

import sys
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
POLICIES_DIR = REPO_ROOT / "conftest" / "policies"
TEMPLATES_DIR = REPO_ROOT / "k3s" / "policies" / "templates"
CONSTRAINTS_DIR = REPO_ROOT / "k3s" / "policies" / "constraints"

MATCH_KINDS = [
    {"apiGroups": ["apps"], "kinds": ["Deployment", "DaemonSet", "StatefulSet", "ReplicaSet"]},
    {"apiGroups": [""], "kinds": ["Pod"]},
]

EXCLUDED_NAMESPACES = ["kube-system", "gatekeeper-system"]


def transform_rego(source: str) -> str:
    """Transform conftest Rego into Gatekeeper-compatible Rego."""
    lines = []
    for line in source.splitlines():
        # Skip metadata comments
        if line.startswith(("# gatekeeper-kind:", "# gatekeeper-name:", "# gatekeeper-exclude:", "# gatekeeper-enforcement:")):
            continue
        lines.append(line)

    rego = "\n".join(lines)

    # Remove package line
    rego = re.sub(r"^package\s+\S+\s*\n", "", rego, flags=re.MULTILINE)

    # Transform: deny/warn contains msg if { ... } → violation[{"msg": msg}] { ... }
    rego = re.sub(r"(?:deny|warn) contains msg if \{", 'violation[{"msg": msg}] {', rego)

    # Transform: input.metadata → input.review.object.metadata (for namespace checks)
    rego = rego.replace("input.metadata.namespace", "input.review.object.metadata.namespace")

    # Transform: input.spec.* → input.review.object.spec.*
    rego = rego.replace("input.spec.", "input.review.object.spec.")

    # Transform: conftest helpers → Gatekeeper paths
    rego = re.sub(r'\bcontainers\[_\]', 'input.review.object.spec.template.spec.containers[_]', rego)
    rego = re.sub(r'\binit_containers\[_\]', 'input.review.object.spec.template.spec.initContainers[_]', rego)
    rego = re.sub(r'\bvolumes\[_\]', 'input.review.object.spec.template.spec.volumes[_]', rego)
    rego = re.sub(r'\bpod_spec\[_\]', 'input.review.object.spec.template.spec', rego)

    return rego


def kind_to_kebab(kind: str) -> str:
    """Convert CamelCase kind to kebab-case: NoRunAsRoot → no-run-as-root."""
    parts = re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?=[A-Z][a-z]|\b)", kind)
    return "-".join(p.lower() for p in parts)


def generate_constraint_template_yAML(kind: str, name: str, rego_body: str) -> str:
    """Generate a Gatekeeper ConstraintTemplate CRD as YAML string."""
    # Indent the rego body for embedding in YAML
    indented_rego = "\n".join("        " + line for line in rego_body.rstrip().splitlines())

    return f"""\
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: {name}
spec:
  crd:
    spec:
      names:
        kind: {kind}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
{indented_rego}
"""


def generate_constraint_yaml(kind: str, name: str, extra_excludes: list[str] | None = None, enforcement: str = "deny") -> str:
    """Generate a Gatekeeper Constraint CRD as YAML string."""
    constraint_name = kind_to_kebab(kind)

    excludes = list(EXCLUDED_NAMESPACES)
    if extra_excludes:
        excludes.extend(extra_excludes)

    excluded_yaml = "\n".join(f"      - {ns}" for ns in excludes)

    enforcement_line = f"\n  enforcementAction: {enforcement}" if enforcement != "deny" else ""

    return f"""\
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: {kind}
metadata:
  name: {constraint_name}
spec:{enforcement_line}
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment", "DaemonSet", "StatefulSet", "ReplicaSet"]
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
{excluded_yaml}
"""


def main():
    errors = False
    templates_generated = 0
    constraints_generated = 0

    TEMPLATES_DIR.mkdir(parents=True, exist_ok=True)
    CONSTRAINTS_DIR.mkdir(parents=True, exist_ok=True)

    rego_files = sorted(POLICIES_DIR.glob("*.rego"))
    if not rego_files:
        print("ERROR: No .rego files found in", POLICIES_DIR)
        sys.exit(1)

    for rego_file in rego_files:
        source = rego_file.read_text()

        # Extract metadata from header comments
        kind_match = re.search(r"^# gatekeeper-kind:\s*(.+)$", source, re.MULTILINE)
        name_match = re.search(r"^# gatekeeper-name:\s*(.+)$", source, re.MULTILINE)

        if not kind_match or not name_match:
            print(f"SKIP: {rego_file.name} (no gatekeeper-kind/name headers — likely a library)")
            continue

        # Extract extra excluded namespaces
        exclude_match = re.findall(r"^# gatekeeper-exclude:\s*(.+)$", source, re.MULTILINE)
        extra_excludes = []
        for exc in exclude_match:
            extra_excludes.extend(ns.strip() for ns in exc.split(","))

        # Extract enforcement action (default: deny)
        enforcement_match = re.search(r"^# gatekeeper-enforcement:\s*(.+)$", source, re.MULTILINE)
        enforcement = enforcement_match.group(1).strip() if enforcement_match else "deny"

        kind = kind_match.group(1).strip()
        name = name_match.group(1).strip()
        basename = rego_file.stem  # e.g. no_run_as_root

        # Transform Rego
        rego_body = transform_rego(source)

        # --- Generate ConstraintTemplate ---
        template_yaml = generate_constraint_template_yAML(kind, name, rego_body)
        template_path = TEMPLATES_DIR / f"{basename}.yaml"
        template_path.write_text(template_yaml)
        templates_generated += 1
        print(f"  Template:  {template_path.relative_to(REPO_ROOT)}")

        # --- Generate Constraint ---
        constraint_yaml = generate_constraint_yaml(kind, name, extra_excludes=extra_excludes if extra_excludes else None, enforcement=enforcement)
        constraint_path = CONSTRAINTS_DIR / f"{basename.replace('_', '-')}.yaml"
        constraint_path.write_text(constraint_yaml)
        constraints_generated += 1
        print(f"  Constraint: {constraint_path.relative_to(REPO_ROOT)}")

    print(f"\nDone: {templates_generated} templates, {constraints_generated} constraints generated")

    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()