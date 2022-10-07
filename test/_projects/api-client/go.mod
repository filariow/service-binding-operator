module api-client

go 1.17

require (
	github.com/redhat-developer/service-binding-operator v0.0.0
	k8s.io/apimachinery v0.22.1
)

replace (
	github.com/mikefarah/yaml/v2 v2.4.0 => gopkg.in/yaml.v2 v2.4.0
	github.com/redhat-developer/service-binding-operator => ../../..
)
