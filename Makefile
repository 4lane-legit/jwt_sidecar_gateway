REPOSITORY=""
NAME="api-gw"
DESCRIPTION="This is a working SSO sidecar for replacing inline implementations of passport and jazz"
VERSION="0.0.1"
FULL_PATH=4lane/$(NAME)


.PHONY: build build-base token local

build-base:
	docker build -t 4lane/resty-base:latest . -f Dockerfile.base

build:
	docker build -t $(FULL_PATH):$(VERSION) .

local:
# https://kind.sigs.k8s.io/docs/user/local-registry/
	chmod +x deploy/k8s/localreg.sh
	sh ./deploy/k8s/localreg.sh

.PHONY: push
push:
	docker push $(FULL_PATH):$(VERSION)

.PHONY: token
	
