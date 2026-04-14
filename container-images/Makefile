#
# This makefile's targets rebuild various container images that can be used
# for development and testing in the CoCo project.
# They also are intended to serve as an up-to-date reference for creating
# new images.
#
# Note: The targets push to ghcr, which requires proper credentials and
# `docker login`.
#
# For multi-arch targets, Docker buildx with QEMU is required:
#   docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
#   docker buildx create --name multiarch-coco --use
#   docker buildx inspect --bootstrap
#

.PHONY: unsig \
	cosign-sig \
	simple-sig \
	enc-unsig \
	enc-cosign-sig \
	test-container-unencrypted \
	test-container-encrypted \
	multi-arch-cosign-sig \
	multi-arch-encrypted \
	multi-arch-encrypted-cosign-sig \
	busybox \
	imgrs-multi-arch-unsigned \
	imgrs-multi-arch-cosign-signed \
	imgrs-multi-arch-cosign-signed-key2 \
	setup-buildx \
	coco-keyprovider \
	all

SHELL := /bin/bash

COCO_PKG := confidential-containers/test-container
COCO_PKG_IMGRS := confidential-containers/test-container-image-rs
REGISTRY := ghcr.io

PLATFORMS := linux/amd64 linux/arm64 linux/s390x
BUILDX_BUILDER := multiarch-coco
KEYPROVIDER_IMAGE := coco-keyprovider
GUEST_COMPONENTS_REF ?= main

SSH_DEMO_KEY_B64 := HUlOu8NWz8si11OZUzUJMnjiq/iZyHBJZMSD3BaqgMc=
SSH_DEMO_KEY_ID := kbs:///default/key/ssh-demo

WORK_DIR := /tmp/coco-multi-arch-build


all: \
	unsig \
	cosign-sig \
	simple-sig \
	enc-unsig \
	enc-cosign-sig \
	test-container-unencrypted \
	test-container-encrypted \
	multi-arch-cosign-sig \
	multi-arch-encrypted \
	multi-arch-encrypted-cosign-sig \
	busybox \
	imgrs-multi-arch-unsigned \
	imgrs-multi-arch-cosign-signed \
	imgrs-multi-arch-cosign-signed-key2


# ---------------------------------------------------------------------------
# Setup targets
# ---------------------------------------------------------------------------

setup-buildx:
	@if ! docker buildx inspect $(BUILDX_BUILDER) >/dev/null 2>&1; then \
		echo "==> Setting up QEMU and buildx builder"; \
		docker run --rm --privileged multiarch/qemu-user-static --reset -p yes; \
		docker buildx create --name $(BUILDX_BUILDER) --use; \
		docker buildx inspect --bootstrap; \
	else \
		docker buildx use $(BUILDX_BUILDER); \
	fi

coco-keyprovider:
	@if ! docker image inspect $(KEYPROVIDER_IMAGE) >/dev/null 2>&1; then \
		echo "==> Building coco-keyprovider from guest-components"; \
		if [ ! -d /tmp/guest-components ]; then \
			git clone --depth 1 --branch $(GUEST_COMPONENTS_REF) \
				https://github.com/confidential-containers/guest-components.git /tmp/guest-components; \
		fi; \
		docker build -t $(KEYPROVIDER_IMAGE) \
			-f /tmp/guest-components/attestation-agent/docker/Dockerfile.keyprovider \
			/tmp/guest-components/; \
	else \
		echo "==> coco-keyprovider image already exists"; \
	fi


# ---------------------------------------------------------------------------
# Single-arch targets (build for host arch, push directly)
# ---------------------------------------------------------------------------

unsig:
	docker build \
		-t $(REGISTRY)/$(COCO_PKG):unsig \
		-f dockerfiles/alpine-with-sshd/Dockerfile \
		.
	docker push $(REGISTRY)/$(COCO_PKG):unsig

cosign-sig:
	docker build \
		-t $(REGISTRY)/$(COCO_PKG):cosign-sig \
		-f dockerfiles/alpine-with-sshd/Dockerfile \
		.
	docker push $(REGISTRY)/$(COCO_PKG):cosign-sig
	${CURDIR}/scripts/make-cosign-sig.sh $(COCO_PKG) cosign-sig $(REGISTRY)

# NOTE: This depends on a gpg key owned by git@runner.com.
# Before issuing this make target:
#   gpg --batch --import ./keys/sign/github-runner.keys
simple-sig: unsig
	skopeo \
		copy \
		--debug \
		--insecure-policy \
		--sign-by git@runner.com \
		--sign-passphrase-file $(shell pwd)/keys/sign/git-runner-password.txt \
		docker-daemon:$(REGISTRY)/$(COCO_PKG):unsig \
		docker://$(REGISTRY)/$(COCO_PKG):simple-sig

# NOTE: This requires coco-keyprovider running on localhost:50000.
# Use `make coco-keyprovider` to build the container, then run it:
#   docker run --rm --network host coco-keyprovider
enc-unsig: unsig
	OCICRYPT_KEYPROVIDER_CONFIG="$(shell pwd)/configs/ocicrypt.conf" \
	skopeo copy \
		--insecure-policy \
		--encryption-key provider:attestation-agent:keypath=$(shell pwd)/keys/encrypt/key1::keyid=kbs:///default/key/key_id1::algorithm=A256GCM \
		docker-daemon:$(REGISTRY)/$(COCO_PKG):unsig \
		docker://$(REGISTRY)/$(COCO_PKG):enc-unsig

enc-cosign-sig: cosign-sig
	OCICRYPT_KEYPROVIDER_CONFIG="$(shell pwd)/configs/ocicrypt.conf" \
	skopeo copy \
		--insecure-policy \
		--encryption-key provider:attestation-agent:keypath=$(shell pwd)/keys/encrypt/key1::keyid=kbs:///default/key/key_id1::algorithm=A256GCM \
		docker-daemon:$(REGISTRY)/$(COCO_PKG):cosign-sig \
		docker://$(REGISTRY)/$(COCO_PKG):enc-cosign-sig
	${CURDIR}/scripts/make-cosign-sig.sh $(COCO_PKG) enc-cosign-sig $(REGISTRY)

test-container-unencrypted:
	docker build \
		-t $(REGISTRY)/$(COCO_PKG):unencrypted \
		-f dockerfiles/alpine-with-sshd/Dockerfile \
		.
	docker push $(REGISTRY)/$(COCO_PKG):unencrypted

test-container-encrypted: test-container-unencrypted
	OCICRYPT_KEYPROVIDER_CONFIG="$(shell pwd)/configs/ocicrypt.conf" \
	skopeo copy \
		--insecure-policy \
		--encryption-key provider:attestation-agent:keypath=$(shell pwd)/keys/encrypt/key1::keyid=kbs:///default/key/key_id1::algorithm=A256GCM \
		docker-daemon:$(REGISTRY)/$(COCO_PKG):unencrypted \
		docker://$(REGISTRY)/$(COCO_PKG):encrypted

busybox:
	docker build \
		-t $(REGISTRY)/$(COCO_PKG_IMGRS):busybox \
		-f dockerfiles/busybox/Dockerfile \
		dockerfiles/busybox
	docker push $(REGISTRY)/$(COCO_PKG_IMGRS):busybox


# ---------------------------------------------------------------------------
# Multi-arch cosign-signed (unencrypted) target
#
# Builds the ccv0-ssh image for each platform, pushes per-arch images,
# assembles a multi-arch manifest, and cosign-signs it.
# ---------------------------------------------------------------------------

multi-arch-cosign-sig: setup-buildx
	@echo "==> Building multi-arch-cosign-sig for: $(PLATFORMS)"
	@for platform in $(PLATFORMS); do \
		arch=$$(echo $$platform | cut -d/ -f2); \
		per_arch_tag="$(REGISTRY)/$(COCO_PKG):cosign-sig-$$arch"; \
		\
		echo "==> [$$arch] Building image"; \
		docker buildx build \
			--platform "$$platform" \
			--provenance=false \
			-t "ccv0-ssh-cosign:$$arch" \
			--load \
			-f dockerfiles/alpine-with-sshd/Dockerfile \
			. ; \
		\
		echo "==> [$$arch] Pushing image"; \
		skopeo copy --insecure-policy --override-arch "$$arch" \
			"docker-daemon:ccv0-ssh-cosign:$$arch" \
			"docker://$$per_arch_tag"; \
	done
	@echo "==> Creating multi-arch manifest"
	@docker manifest rm $(REGISTRY)/$(COCO_PKG):multi-arch-cosign-sig 2>/dev/null || true
	@docker manifest create $(REGISTRY)/$(COCO_PKG):multi-arch-cosign-sig \
		$(foreach p,$(PLATFORMS),$(REGISTRY)/$(COCO_PKG):cosign-sig-$(lastword $(subst /, ,$(p))))
	@$(foreach p,$(PLATFORMS), \
		docker manifest annotate $(REGISTRY)/$(COCO_PKG):multi-arch-cosign-sig \
			$(REGISTRY)/$(COCO_PKG):cosign-sig-$(lastword $(subst /, ,$(p))) \
			--os linux --arch $(lastword $(subst /, ,$(p))) ; \
	)
	@echo "==> Pushing multi-arch manifest"
	@docker manifest push $(REGISTRY)/$(COCO_PKG):multi-arch-cosign-sig
	@echo "==> Cosign-signing multi-arch-cosign-sig"
	${CURDIR}/scripts/make-cosign-sig.sh $(COCO_PKG) multi-arch-cosign-sig $(REGISTRY)
	@echo "==> Done! Image: $(REGISTRY)/$(COCO_PKG):multi-arch-cosign-sig"


# ---------------------------------------------------------------------------
# Multi-arch encrypted target
#
# Builds the ccv0-ssh image for each platform, encrypts with the
# coco-keyprovider container, pushes per-arch images, and assembles
# a multi-arch manifest.
#
# Encryption key: from demos/ssh-demo/aa-offline_fs_kbc-keys.json
# Key ID:         kbs:///default/key/ssh-demo
# ---------------------------------------------------------------------------

multi-arch-encrypted: setup-buildx coco-keyprovider
	@echo "==> Building multi-arch-encrypted for: $(PLATFORMS)"
	@mkdir -p $(WORK_DIR)
	@for platform in $(PLATFORMS); do \
		arch=$$(echo $$platform | cut -d/ -f2); \
		arch_dir="$(WORK_DIR)/$$arch"; \
		per_arch_tag="$(REGISTRY)/$(COCO_PKG):encrypted-$$arch"; \
		\
		echo "==> [$$arch] Building unencrypted image"; \
		docker buildx build \
			--platform "$$platform" \
			--provenance=false \
			-t "ccv0-ssh:$$arch" \
			--load \
			-f dockerfiles/alpine-with-sshd/Dockerfile \
			. ; \
		\
		echo "==> [$$arch] Exporting to OCI directory"; \
		mkdir -p "$$arch_dir"/{input,output}; \
		skopeo copy --insecure-policy --override-arch "$$arch" \
			"docker-daemon:ccv0-ssh:$$arch" \
			"dir:$$arch_dir/input"; \
		\
		echo "==> [$$arch] Encrypting with coco-keyprovider"; \
		docker run --rm \
			-v "$$arch_dir:/oci" \
			$(KEYPROVIDER_IMAGE) \
			/encrypt.sh \
				-k "$(SSH_DEMO_KEY_B64)" \
				-i "$(SSH_DEMO_KEY_ID)" \
				-s "dir:/oci/input" \
				-d "dir:/oci/output"; \
		\
		echo "==> [$$arch] Verifying encryption annotations"; \
		skopeo inspect "dir:$$arch_dir/output" \
			| jq -e 'any(.LayersData[]?; .Annotations?["org.opencontainers.image.enc.keys.provider.attestation-agent"] != null)' \
			|| { echo "ERROR: [$$arch] No encryption annotation"; exit 1; }; \
		\
		echo "==> [$$arch] Pushing encrypted image"; \
		skopeo copy --insecure-policy "dir:$$arch_dir/output" "docker://$$per_arch_tag"; \
	done
	@echo "==> Creating multi-arch manifest"
	@docker manifest rm $(REGISTRY)/$(COCO_PKG):multi-arch-encrypted 2>/dev/null || true
	@docker manifest create $(REGISTRY)/$(COCO_PKG):multi-arch-encrypted \
		$(foreach p,$(PLATFORMS),$(REGISTRY)/$(COCO_PKG):encrypted-$(lastword $(subst /, ,$(p))))
	@$(foreach p,$(PLATFORMS), \
		docker manifest annotate $(REGISTRY)/$(COCO_PKG):multi-arch-encrypted \
			$(REGISTRY)/$(COCO_PKG):encrypted-$(lastword $(subst /, ,$(p))) \
			--os linux --arch $(lastword $(subst /, ,$(p))) ; \
	)
	@echo "==> Pushing multi-arch manifest"
	@docker manifest push $(REGISTRY)/$(COCO_PKG):multi-arch-encrypted
	@echo "==> Done! Image: $(REGISTRY)/$(COCO_PKG):multi-arch-encrypted"


# ---------------------------------------------------------------------------
# Multi-arch encrypted + cosign-signed target
#
# Re-tags the per-arch encrypted images under a new manifest and
# cosign-signs it, producing an image that is both encrypted and
# cosign-signed under a separate tag.
# ---------------------------------------------------------------------------

multi-arch-encrypted-cosign-sig: multi-arch-encrypted
	@echo "==> Creating multi-arch-encrypted-cosign-sig manifest"
	@docker manifest rm $(REGISTRY)/$(COCO_PKG):multi-arch-encrypted-cosign-sig 2>/dev/null || true
	@docker manifest create $(REGISTRY)/$(COCO_PKG):multi-arch-encrypted-cosign-sig \
		$(foreach p,$(PLATFORMS),$(REGISTRY)/$(COCO_PKG):encrypted-$(lastword $(subst /, ,$(p))))
	@$(foreach p,$(PLATFORMS), \
		docker manifest annotate $(REGISTRY)/$(COCO_PKG):multi-arch-encrypted-cosign-sig \
			$(REGISTRY)/$(COCO_PKG):encrypted-$(lastword $(subst /, ,$(p))) \
			--os linux --arch $(lastword $(subst /, ,$(p))) ; \
	)
	@echo "==> Pushing multi-arch-encrypted-cosign-sig manifest"
	@docker manifest push $(REGISTRY)/$(COCO_PKG):multi-arch-encrypted-cosign-sig
	@echo "==> Cosign-signing multi-arch-encrypted-cosign-sig"
	${CURDIR}/scripts/make-cosign-sig.sh $(COCO_PKG) multi-arch-encrypted-cosign-sig $(REGISTRY)
	@echo "==> Done! Image: $(REGISTRY)/$(COCO_PKG):multi-arch-encrypted-cosign-sig"


# ---------------------------------------------------------------------------
# Multi-arch test-container-image-rs targets
#
# These produce multi-arch manifests under COCO_PKG_IMGRS for use by
# kata-containers image-signature verification tests.
# ---------------------------------------------------------------------------

imgrs-multi-arch-unsigned: setup-buildx
	@echo "==> Building imgrs-multi-arch-unsigned for: $(PLATFORMS)"
	@for platform in $(PLATFORMS); do \
		arch=$$(echo $$platform | cut -d/ -f2); \
		per_arch_tag="$(REGISTRY)/$(COCO_PKG_IMGRS):unsigned-$$arch"; \
		\
		echo "==> [$$arch] Building image"; \
		docker buildx build \
			--platform "$$platform" \
			--provenance=false \
			--no-cache \
			--build-arg IMAGE_VARIANT=unsigned \
			-t "imgrs-unsigned:$$arch" \
			--load \
			-f dockerfiles/busybox/Dockerfile \
			dockerfiles/busybox ; \
		\
		echo "==> [$$arch] Pushing image"; \
		skopeo copy --insecure-policy --override-arch "$$arch" \
			"docker-daemon:imgrs-unsigned:$$arch" \
			"docker://$$per_arch_tag"; \
	done
	@echo "==> Creating multi-arch manifest"
	@docker manifest rm $(REGISTRY)/$(COCO_PKG_IMGRS):unsigned 2>/dev/null || true
	@docker manifest create $(REGISTRY)/$(COCO_PKG_IMGRS):unsigned \
		$(foreach p,$(PLATFORMS),$(REGISTRY)/$(COCO_PKG_IMGRS):unsigned-$(lastword $(subst /, ,$(p))))
	@$(foreach p,$(PLATFORMS), \
		docker manifest annotate $(REGISTRY)/$(COCO_PKG_IMGRS):unsigned \
			$(REGISTRY)/$(COCO_PKG_IMGRS):unsigned-$(lastword $(subst /, ,$(p))) \
			--os linux --arch $(lastword $(subst /, ,$(p))) ; \
	)
	@echo "==> Pushing multi-arch manifest"
	@docker manifest push $(REGISTRY)/$(COCO_PKG_IMGRS):unsigned
	@echo "==> Done! Image: $(REGISTRY)/$(COCO_PKG_IMGRS):unsigned"

imgrs-multi-arch-cosign-signed: setup-buildx
	@echo "==> Building imgrs-multi-arch-cosign-signed for: $(PLATFORMS)"
	@for platform in $(PLATFORMS); do \
		arch=$$(echo $$platform | cut -d/ -f2); \
		per_arch_tag="$(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-$$arch"; \
		\
		echo "==> [$$arch] Building image"; \
		docker buildx build \
			--platform "$$platform" \
			--provenance=false \
			--no-cache \
			--build-arg IMAGE_VARIANT=cosign-signed \
			-t "imgrs-cosign-signed:$$arch" \
			--load \
			-f dockerfiles/busybox/Dockerfile \
			dockerfiles/busybox ; \
		\
		echo "==> [$$arch] Pushing image"; \
		skopeo copy --insecure-policy --override-arch "$$arch" \
			"docker-daemon:imgrs-cosign-signed:$$arch" \
			"docker://$$per_arch_tag"; \
		\
		echo "==> [$$arch] Cosign-signing per-arch image"; \
		${CURDIR}/scripts/make-cosign-sig.sh $(COCO_PKG_IMGRS) cosign-signed-$$arch $(REGISTRY); \
	done
	@echo "==> Creating multi-arch manifest"
	@docker manifest rm $(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed 2>/dev/null || true
	@docker manifest create $(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed \
		$(foreach p,$(PLATFORMS),$(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-$(lastword $(subst /, ,$(p))))
	@$(foreach p,$(PLATFORMS), \
		docker manifest annotate $(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed \
			$(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-$(lastword $(subst /, ,$(p))) \
			--os linux --arch $(lastword $(subst /, ,$(p))) ; \
	)
	@echo "==> Pushing multi-arch manifest"
	@docker manifest push $(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed
	@echo "==> Cosign-signing manifest list"
	${CURDIR}/scripts/make-cosign-sig.sh $(COCO_PKG_IMGRS) cosign-signed $(REGISTRY)
	@echo "==> Done! Image: $(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed"

imgrs-multi-arch-cosign-signed-key2: setup-buildx
	@echo "==> Building imgrs-multi-arch-cosign-signed-key2 for: $(PLATFORMS)"
	@for platform in $(PLATFORMS); do \
		arch=$$(echo $$platform | cut -d/ -f2); \
		per_arch_tag="$(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-key2-$$arch"; \
		\
		echo "==> [$$arch] Building image"; \
		docker buildx build \
			--platform "$$platform" \
			--provenance=false \
			--no-cache \
			--build-arg IMAGE_VARIANT=cosign-signed-key2 \
			-t "imgrs-cosign-signed-key2:$$arch" \
			--load \
			-f dockerfiles/busybox/Dockerfile \
			dockerfiles/busybox ; \
		\
		echo "==> [$$arch] Pushing image"; \
		skopeo copy --insecure-policy --override-arch "$$arch" \
			"docker-daemon:imgrs-cosign-signed-key2:$$arch" \
			"docker://$$per_arch_tag"; \
		\
		echo "==> [$$arch] Cosign-signing per-arch image with key2"; \
		COSIGN_PASSWORD="$${COSIGN_PASSWORD_KEY2}" cosign sign --yes --key keys/sign/cosign2.key \
			"$(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-key2-$$arch"; \
	done
	@echo "==> Creating multi-arch manifest"
	@docker manifest rm $(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-key2 2>/dev/null || true
	@docker manifest create $(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-key2 \
		$(foreach p,$(PLATFORMS),$(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-key2-$(lastword $(subst /, ,$(p))))
	@$(foreach p,$(PLATFORMS), \
		docker manifest annotate $(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-key2 \
			$(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-key2-$(lastword $(subst /, ,$(p))) \
			--os linux --arch $(lastword $(subst /, ,$(p))) ; \
	)
	@echo "==> Pushing multi-arch manifest"
	@docker manifest push $(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-key2
	@echo "==> Cosign-signing manifest list with key2"
	COSIGN_PASSWORD="$${COSIGN_PASSWORD_KEY2}" cosign sign --yes --key keys/sign/cosign2.key "$(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-key2"
	@echo "==> Done! Image: $(REGISTRY)/$(COCO_PKG_IMGRS):cosign-signed-key2"
