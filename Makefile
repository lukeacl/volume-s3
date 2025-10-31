IMAGE_NAME := lukeacl/volume-s3
IMAGE_TAG := latest

build:
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_NAME):$(IMAGE_TAG) .

push:
	docker push $(IMAGE_NAME):$(IMAGE_TAG)

test:
	docker compose up --build app
