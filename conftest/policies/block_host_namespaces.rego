package main

# gatekeeper-kind: BlockHostNamespaces
# gatekeeper-name: blockhostnamespaces
# gatekeeper-exclude: infra

deny contains msg if {
	spec := pod_spec[_]
	spec.hostNetwork == true
	not input.metadata.namespace == "infra"
	msg := "hostNetwork is not allowed"
}

deny contains msg if {
	spec := pod_spec[_]
	spec.hostPID == true
	not input.metadata.namespace == "infra"
	msg := "hostPID is not allowed"
}

deny contains msg if {
	spec := pod_spec[_]
	spec.hostIPC == true
	not input.metadata.namespace == "infra"
	msg := "hostIPC is not allowed"
}