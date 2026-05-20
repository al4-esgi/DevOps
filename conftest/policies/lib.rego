package main

# Helper: extract all containers (containers + initContainers) from any K8s workload.
# For Pod:          input.spec.containers
# For Deployment:   input.spec.template.spec.containers
# For CronJob:      input.spec.jobTemplate.spec.template.spec.containers

containers contains container if {
	input.kind == "Pod"
	container := input.spec.containers[_]
}

containers contains container if {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
}

containers contains container if {
	input.kind == "DaemonSet"
	container := input.spec.template.spec.containers[_]
}

containers contains container if {
	input.kind == "StatefulSet"
	container := input.spec.template.spec.containers[_]
}

containers contains container if {
	input.kind == "ReplicaSet"
	container := input.spec.template.spec.containers[_]
}

containers contains container if {
	input.kind == "CronJob"
	container := input.spec.jobTemplate.spec.template.spec.containers[_]
}

containers contains container if {
	input.kind == "Job"
	container := input.spec.template.spec.containers[_]
}

init_containers contains container if {
	input.kind == "Pod"
	container := input.spec.initContainers[_]
}

init_containers contains container if {
	input.kind == "Deployment"
	container := input.spec.template.spec.initContainers[_]
}

init_containers contains container if {
	input.kind == "DaemonSet"
	container := input.spec.template.spec.initContainers[_]
}

init_containers contains container if {
	input.kind == "StatefulSet"
	container := input.spec.template.spec.initContainers[_]
}

init_containers contains container if {
	input.kind == "ReplicaSet"
	container := input.spec.template.spec.initContainers[_]
}

init_containers contains container if {
	input.kind == "CronJob"
	container := input.spec.jobTemplate.spec.template.spec.initContainers[_]
}

init_containers contains container if {
	input.kind == "Job"
	container := input.spec.template.spec.initContainers[_]
}

volumes contains volume if {
	input.kind == "Pod"
	volume := input.spec.volumes[_]
}

volumes contains volume if {
	input.kind == "Deployment"
	volume := input.spec.template.spec.volumes[_]
}

volumes contains volume if {
	input.kind == "DaemonSet"
	volume := input.spec.template.spec.volumes[_]
}

volumes contains volume if {
	input.kind == "StatefulSet"
	volume := input.spec.template.spec.volumes[_]
}

volumes contains volume if {
	input.kind == "ReplicaSet"
	volume := input.spec.template.spec.volumes[_]
}

volumes contains volume if {
	input.kind == "CronJob"
	volume := input.spec.jobTemplate.spec.template.spec.volumes[_]
}

volumes contains volume if {
	input.kind == "Job"
	volume := input.spec.template.spec.volumes[_]
}

pod_spec contains spec if {
	input.kind == "Pod"
	spec := input.spec
}

pod_spec contains spec if {
	input.kind == "Deployment"
	spec := input.spec.template.spec
}

pod_spec contains spec if {
	input.kind == "DaemonSet"
	spec := input.spec.template.spec
}

pod_spec contains spec if {
	input.kind == "StatefulSet"
	spec := input.spec.template.spec
}

pod_spec contains spec if {
	input.kind == "ReplicaSet"
	spec := input.spec.template.spec
}

pod_spec contains spec if {
	input.kind == "CronJob"
	spec := input.spec.jobTemplate.spec.template.spec
}

pod_spec contains spec if {
	input.kind == "Job"
	spec := input.spec.template.spec
}