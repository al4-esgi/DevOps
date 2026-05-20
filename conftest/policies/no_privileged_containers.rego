package main

# gatekeeper-kind: NoPrivilegedContainers
# gatekeeper-name: noprivilegedcontainers

deny contains msg if {
	container := input.spec.containers[_]
	container.securityContext.privileged == true
	msg := sprintf("Privileged containers are not allowed: %v", [container.name])
}

deny contains msg if {
	container := input.spec.initContainers[_]
	container.securityContext.privileged == true
	msg := sprintf("Privileged init containers are not allowed: %v", [container.name])
}