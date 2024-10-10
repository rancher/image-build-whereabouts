SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)
ARCH=
ifeq ($(UNAME_M), x86_64)
	ARCH=amd64
else ifeq ($(UNAME_M), aarch64)
	ARCH=arm64
else 
	ARCH=$(UNAME_M)
endif

ifndef TARGET_PLATFORMS
	ifeq ($(UNAME_M), x86_64)
		TARGET_PLATFORMS:=linux/amd64
	else ifeq ($(UNAME_M), aarch64)
		TARGET_PLATFORMS:=linux/arm64
	else 
		TARGET_PLATFORMS:=linux/$(UNAME_M)
	endif
endif

BUILD_META=-build$(shell date +%Y%m%d)
ORG ?= rancher
PKG ?= github.com/k8snetworkplumbingwg/whereabouts
SRC ?= github.com/k8snetworkplumbingwg/whereabouts
TAG ?= ${GITHUB_ACTION_TAG}

ifeq ($(TAG),)
TAG := v0.8.0$(BUILD_META)
endif

IMAGE ?= $(ORG)/hardened-whereabouts:$(TAG)

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG $(TAG) needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build
image-build:
	docker buildx build \
		--platform=$(ARCH) \
		--pull \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--tag $(IMAGE) \
		--tag $(IMAGE)-$(ARCH) \
		--load \
		.

.PHONY: push-image
push-image:
	docker buildx build \
		$(IID_FILE_FLAG) \
		--sbom=true \
		--attest type=provenance,mode=max \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--tag $(IMAGE) \
		--tag $(IMAGE)-$(ARCH) \
		--push \
		.

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-whereabouts:$(TAG)-$(ARCH)

.PHONY: image-scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed image $(ORG)/hardened-whereabouts:$(TAG)

PHONY: log
log:
	@echo "ARCH=$(ARCH)"
	@echo "TAG=$(TAG:$(BUILD_META)=)"
	@echo "ORG=$(ORG)"
	@echo "PKG=$(PKG)"
	@echo "SRC=$(SRC)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"
