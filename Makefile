REPOSITORY=""
NAME="api-gw-service-mesh-token"
DESCRIPTION="This is a working JWT token auth sidecar for replacing inline implementations of passport and jazz"
VERSION="0.0.1"
FULL_PATH=lanerunner/dev/$(NAME)


.PHONY: build build-base

build-base:
	docker build -t lanerunner:latest . -f Dockerfile.base

build:
	docker build -t $(FULL_PATH):$(VERSION) .

.PHONY: push
push:
	docker push $(FULL_PATH):$(VERSION)

.PHONY: token
	
