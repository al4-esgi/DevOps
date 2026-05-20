package main

# gatekeeper-kind: NoPrivilegeEscalation
# gatekeeper-name: noprivilegeescalation

deny contains msg if {
	container := containers[_]
	container.securityContext.allowPrivilegeEscalation == true
	msg := sprintf("allowPrivilegeEscalation is not allowed: %v", [container.name])
}