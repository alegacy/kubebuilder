FROM golang:1.10.3 as dlvbuilder

# Build delve debugger
RUN apt-get update && apt-get install -y git
RUN go get github.com/derekparker/delve/cmd/dlv

FROM dlvbuilder as builder
ARG GOBUILD_GCFLAGS=""

# Copy in the go src
WORKDIR /go/src/sigs.k8s.io/kubebuilder/test/project

COPY pkg/    pkg/
COPY cmd/    cmd/
COPY vendor/ vendor/

# Build manager
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -gcflags "${GOBUILD_GCFLAGS}" -a -o manager sigs.k8s.io/kubebuilder/test/project/cmd/manager

# Copy the controller-manager into a thin image
FROM ubuntu:latest as production
WORKDIR /
COPY --from=builder /go/src/sigs.k8s.io/kubebuilder/test/project/manager .

CMD "/manager"

# Copy the delve debugger into a debug image
FROM production as debug
WORKDIR /
COPY --from=dlvbuilder /go/bin/dlv /

CMD ["/dlv-wrapper.sh", "/manager"]
