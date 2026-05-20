package main

# gatekeeper-kind: BlockHostPath
# gatekeeper-name: blockhostpath

deny contains msg if {
	volume := volumes[_]
	volume.hostPath
	msg := sprintf("hostPath volumes are not allowed: %v", [volume.name])
}