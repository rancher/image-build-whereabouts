ARG BCI_IMAGE=registry.suse.com/bci/bci-base:15.4
ARG GO_IMAGE=rancher/hardened-build-base:v1.19.7b1
FROM ${BCI_IMAGE} as bci

FROM ${GO_IMAGE} as builder
ARG ARCH="amd64"
ARG TAG="v0.6.1"
ARG PKG="github.com/k8snetworkplumbingwg/whereabouts"
ARG SRC="github.com/k8snetworkplumbingwg/whereabouts"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}

ENV GO111MODULE=on
RUN GIT_SHA=$(git rev-parse --short HEAD) \
    GIT_TREE_STATE=$(test -n "`git status --porcelain --untracked-files=no`" && echo "dirty" || echo "clean") \ 
&& export GO_LDFLAGS="-X ${PKG}/pkg/version.Version=${TAG} \
    -X ${PKG}/pkg/version.GitSHA=${GIT_SHA} \
    -X ${PKG}/pkg/version.GitTreeState=${GIT_TREE_STATE}" \
&& go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod vendor -o bin/whereabouts cmd/whereabouts.go \
&& go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod vendor -o bin/ip-control-loop cmd/controlloop/*.go
RUN go-assert-boring.sh bin/*
RUN install -s bin/* /usr/local/bin
RUN whereabouts --version

FROM bci
COPY --from=builder /usr/local/bin/whereabouts   .
COPY --from=builder /usr/local/bin/ip-control-loop .
ARG PKG="github.com/k8snetworkplumbingwg/whereabouts"
COPY --from=builder /go/src/${PKG}/script/install-cni.sh .
CMD ["/install-cni.sh"]
