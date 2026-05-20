package main

# gatekeeper-kind: RequireResourceLimits
# gatekeeper-name: requireresourcelimits

deny contains msg if {
	container := containers[_]
	not container.resources.limits
	msg := sprintf("Containers must have resource limits: %v", [container.name])
}

deny contains msg if {
	container := containers[_]
	not container.resources.limits.cpu
	msg := sprintf("Containers must have CPU limits: %v", [container.name])
}

deny contains msg if {
	container := containers[_]
	not container.resources.limits.memory
	msg := sprintf("Containers must have memory limits: %v", [container.name])
}