package main

# gatekeeper-kind: NoRunAsRoot
# gatekeeper-name: norunasroot

deny contains msg if {
	container := input.spec.containers[_]
	not container.securityContext.runAsNonRoot
	msg := sprintf("Containers must run as non-root: %v", [container.name])
}

deny contains msg if {
	container := input.spec.containers[_]
	container.securityContext.runAsNonRoot == false
	msg := sprintf("Containers must not set runAsNonRoot to false: %v", [container.name])
}