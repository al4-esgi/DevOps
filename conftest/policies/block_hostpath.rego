package main

# gatekeeper-kind: BlockHostPath
# gatekeeper-name: blockhostpath

deny contains msg if {
	volume := input.spec.volumes[_]
	volume.hostPath
	msg := sprintf("hostPath volumes are not allowed: %v", [volume.name])
}