
# Image URL to use all building/pushing image targets
IMG ?= controller:latest

ifeq (${DEBUG}, yes)
	DOCKER_TARGET = debug
	KUSTOMIZE_OVERLAY = debug
	GOBUILD_GCFLAGS = all=-N -l
else
	DOCKER_TARGET = production
	KUSTOMIZE_OVERLAY = default
	GOBUILD_GCFLAGS = ""
endif

all: test manager

# Run tests
test: generate fmt vet manifests
	go test ./pkg/... ./cmd/... -coverprofile cover.out

# Build manager binary
manager: generate fmt vet
	go build -gcflags "${GOBUILD_GCFLAGS}" -o bin/manager sigs.k8s.io/kubebuilder/test/project/cmd/manager

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet
	go run ./cmd/manager/main.go

# Run the manager locally and wrapped with delve for debugging
debug: manager
	dlv --listen=:30000 --headless=true --api-version=2 --accept-multiclient exec bin/manager

# Install CRDs into a cluster
install: manifests
	kubectl apply -f config/crds

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests
	kubectl apply -f config/crds
	kustomize build config/${KUSTOMIZE_OVERLAY} | kubectl apply -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests:
	go run vendor/sigs.k8s.io/controller-tools/cmd/controller-gen/main.go all

# Run go fmt against code
fmt:
	go fmt ./pkg/... ./cmd/...

# Run go vet against code
vet:
	go vet ./pkg/... ./cmd/...

# Generate code
generate:
ifndef GOPATH
	$(error GOPATH not defined, please define GOPATH. Run "go help gopath" to learn more about GOPATH)
endif
	go generate ./pkg/... ./cmd/...

# Build the docker image
docker-build: test
	docker build . -t ${IMG} --target ${DOCKER_TARGET} --build-arg "GOBUILD_GCFLAGS=${GOBUILD_GCFLAGS}"
	@echo "updating kustomize image patch file for manager resource"
	sed -i'' -e 's@image: .*@image: '"${IMG}"'@' ./config/${KUSTOMIZE_OVERLAY}/manager_image_patch.yaml

# Push the docker image
docker-push:
	docker push ${IMG}
