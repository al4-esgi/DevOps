package main

# gatekeeper-kind: BlockLatestTag
# gatekeeper-name: blocklatesttag

deny contains msg if {
	container := containers[_]
	endswith(container.image, ":latest")
	msg := sprintf("Using :latest image tag is not allowed: %v", [container.image])
}

deny contains msg if {
	container := containers[_]
	not contains(container.image, ":")
	msg := sprintf("Image must specify a tag (no :latest implicit): %v", [container.image])
}

deny contains msg if {
	container := init_containers[_]
	endswith(container.image, ":latest")
	msg := sprintf("Using :latest image tag is not allowed: %v", [container.image])
}