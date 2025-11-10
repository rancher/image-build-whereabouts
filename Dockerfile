ARG BCI_IMAGE=registry.suse.com/bci/bci-busybox
ARG GO_IMAGE=rancher/hardened-build-base:v1.24.10b1
FROM ${BCI_IMAGE} AS bci

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.8.0 AS xx

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS base-builder
# copy xx scripts to your build stage
COPY --from=xx / /
RUN apk add file make git clang lld
ARG TARGETPLATFORM
RUN set -x && \
    xx-apk --no-cache add musl-dev gcc

FROM base-builder AS whereabouts-builder
ARG TAG=v0.9.2
ARG PKG="github.com/k8snetworkplumbingwg/whereabouts"
ARG SRC="github.com/k8snetworkplumbingwg/whereabouts"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN go mod download
# cross-compilation setup
ARG TARGETARCH

ENV GO111MODULE=on
RUN GIT_COMMIT=$(git rev-parse --short HEAD) \
    export GO_LDFLAGS=" \
    -X ${PKG}/pkg/version.Version=${TAG} \
    -X ${PKG}/pkg/version.GitCommit=${GIT_COMMIT} \
    " && xx-go --wrap && \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod vendor -o bin/whereabouts ./cmd/ && \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod vendor -o bin/ip-control-loop ./cmd/controlloop/ && \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod vendor -o bin/node-slice-controller ./cmd/nodeslicecontroller/
RUN go-assert-boring.sh bin/*
RUN xx-verify --static bin/*
RUN install bin/* /usr/local/bin

FROM ${GO_IMAGE} AS strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=whereabouts-builder /usr/local/bin/whereabouts   .
COPY --from=whereabouts-builder /usr/local/bin/ip-control-loop .
COPY --from=whereabouts-builder /usr/local/bin/node-slice-controller . 
RUN strip ./whereabouts ./ip-control-loop ./node-slice-controller

FROM bci
COPY --from=strip_binary /go/whereabouts .
COPY --from=strip_binary /go/ip-control-loop .
COPY --from=strip_binary /go/node-slice-controller .
ARG PKG="github.com/k8snetworkplumbingwg/whereabouts"
COPY --from=whereabouts-builder /go/src/${PKG}/script/install-cni.sh .
COPY --from=whereabouts-builder /go/src/${PKG}/script/lib.sh .
COPY --from=whereabouts-builder /go/src/${PKG}/script/token-watcher.sh .
ARG BCI_IMAGE
LABEL org.opencontainers.image.url="https://hub.docker.com/r/rancher/hardened-whereabouts"
LABEL org.opencontainers.image.source="https://github.com/rancher/image-build-whereabouts"
LABEL org.opencontainers.image.base.name="${BCI_IMAGE}"
CMD ["/install-cni.sh"]
