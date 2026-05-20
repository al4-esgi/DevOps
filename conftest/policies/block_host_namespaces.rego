package main

# gatekeeper-kind: BlockHostNamespaces
# gatekeeper-name: blockhostnamespaces

deny contains msg if {
	spec := pod_spec[_]
	spec.hostNetwork == true
	msg := "hostNetwork is not allowed"
}

deny contains msg if {
	spec := pod_spec[_]
	spec.hostPID == true
	msg := "hostPID is not allowed"
}

deny contains msg if {
	spec := pod_spec[_]
	spec.hostIPC == true
	msg := "hostIPC is not allowed"
}