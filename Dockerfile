ARG BCI_IMAGE=registry.suse.com/bci/bci-base:15.3.17.20.12
ARG GO_IMAGE=rancher/hardened-build-base:v1.16.15b7
FROM ${BCI_IMAGE} as bci

FROM ${GO_IMAGE} as builder
ARG ARCH="amd64"
ARG TAG="v0.5.3"
ARG PKG="github.com/k8snetworkplumbingwg/whereabouts"
ARG SRC="github.com/k8snetworkplumbingwg/whereabouts"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
ENV GO_LDFLAGS="-X ${PKG}/version.Version=${TAG}"
ENV GO111MODULE=on
RUN go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod vendor -o bin/whereabouts cmd/whereabouts.go
RUN go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod vendor -o bin/ip-reconciler cmd/reconciler/ip.go cmd/reconciler/errors.go
RUN go-assert-boring.sh bin/*
RUN install -s bin/* /usr/local/bin
RUN whereabouts --version

FROM bci
COPY --from=builder /usr/local/bin/whereabouts   .
COPY --from=builder /usr/local/bin/ip-reconciler .
ARG PKG="github.com/k8snetworkplumbingwg/whereabouts"
COPY --from=builder /go/src/${PKG}/script/install-cni.sh .
CMD ["/install-cni.sh"]
