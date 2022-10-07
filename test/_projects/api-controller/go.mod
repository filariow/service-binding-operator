module api-controller

go 1.17

require (
	github.com/redhat-developer/service-binding-operator v0.0.0
	k8s.io/apimachinery v0.22.1
	sigs.k8s.io/controller-runtime v0.10.0
)

replace (
	github.com/mikefarah/yaml/v2 v2.4.0 => gopkg.in/yaml.v2 v2.4.0
	github.com/redhat-developer/service-binding-operator => ../../..
)
