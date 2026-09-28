SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)
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
TAG ?= ${GITHUB_ACTION_TAG}

ifeq ($(TAG),)
TAG := $(shell cat TAG)$(BUILD_META)
endif

REPO ?= rancher
IMAGE ?= $(REPO)/hardened-whereabouts:$(TAG)

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG $(TAG) needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build
image-build:
	docker buildx build \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--tag $(IMAGE) \
		--load \
		.

.PHONY: push-image
push-image:
	docker buildx build \
		$(IID_FILE_FLAG) \
		--sbom=true \
		--attest type=provenance,mode=max \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--tag $(IMAGE) \
		--push \
		.

.PHONY: image-push
image-push:
	docker push $(IMAGE)

.PHONY: image-scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed image $(IMAGE)

PHONY: log
log:
	@echo "TAG=$(TAG:$(BUILD_META)=)"
	@echo "REPO=$(REPO)"
	@echo "IMAGE=$(IMAGE)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"
	@echo "TARGET_PLATFORMS=$(TARGET_PLATFORMS)"
