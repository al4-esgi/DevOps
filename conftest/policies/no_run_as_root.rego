package main

# gatekeeper-kind: NoRunAsRoot
# gatekeeper-name: norunasroot
# gatekeeper-enforcement: warn

warn contains msg if {
	container := containers[_]
	not container.securityContext.runAsNonRoot
	msg := sprintf("Containers should run as non-root: %v", [container.name])
}

warn contains msg if {
	container := containers[_]
	container.securityContext.runAsNonRoot == false
	msg := sprintf("Containers must not set runAsNonRoot to false: %v", [container.name])
}