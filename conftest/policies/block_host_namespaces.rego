package main

# gatekeeper-kind: BlockHostNamespaces
# gatekeeper-name: blockhostnamespaces

deny contains msg if {
	input.spec.hostNetwork == true
	msg := "hostNetwork is not allowed"
}

deny contains msg if {
	input.spec.hostPID == true
	msg := "hostPID is not allowed"
}

deny contains msg if {
	input.spec.hostIPC == true
	msg := "hostIPC is not allowed"
}