package main

# gatekeeper-kind: RestrictCapabilities
# gatekeeper-name: restrictcapabilities

forbidden_caps := {"NET_RAW", "SYS_ADMIN", "SYS_PTRACE", "KILL", "DAC_OVERRIDE"}

deny contains msg if {
	container := input.spec.containers[_]
	cap := container.securityContext.capabilities.add[_]
	forbidden_caps[cap]
	msg := sprintf("Forbidden Linux capability %v in container %v", [cap, container.name])
}