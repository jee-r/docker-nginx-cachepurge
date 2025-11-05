.PHONY: help fetch build test clean run stop logs

IMAGE_NAME ?= nginx-cachepurge
NGINX_VERSION ?= mainline
ENABLED_MODULES ?= cachepurge
DOCKERFILE_URL = https://raw.githubusercontent.com/nginx/docker-nginx/master/modules/Dockerfile

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

fetch: ## Fetch the official nginx modules Dockerfile
	@echo "Fetching Dockerfile from nginx/docker-nginx..."
	@curl -fsSL -o Dockerfile $(DOCKERFILE_URL)
	@echo "Dockerfile downloaded successfully"

build: fetch ## Fetch Dockerfile and build the image
	@echo "Building $(IMAGE_NAME):latest..."
	docker build --network host \
		--build-arg NGINX_FROM_IMAGE=nginx:$(NGINX_VERSION) \
		--build-arg ENABLED_MODULES=$(ENABLED_MODULES) \
		-t $(IMAGE_NAME):latest \
		.

test: build ## Build and test the image
	@echo "Testing nginx configuration..."
	docker run --rm $(IMAGE_NAME):latest nginx -t
	@echo ""
	@echo "Checking if module file exists..."
	docker run --rm $(IMAGE_NAME):latest ls -la /usr/lib/nginx/modules/ngx_http_cache_purge_module.so
	@echo ""
	@echo "Testing module loading..."
	docker run --rm $(IMAGE_NAME):latest sh -c \
		"mkdir -p /etc/nginx/modules-enabled && \
		echo 'load_module modules/ngx_http_cache_purge_module.so;' > /etc/nginx/modules-enabled/cache_purge.conf && \
		sed -i '1i include /etc/nginx/modules-enabled/*.conf;' /etc/nginx/nginx.conf && \
		nginx -t && \
		nginx -T 2>&1 | grep -q 'load_module modules/ngx_http_cache_purge_module.so'"
	@echo ""
	@echo "Testing nginx startup..."
	@CONTAINER_ID=$$(docker run --rm -d $(IMAGE_NAME):latest) && \
		sleep 2 && \
		if docker ps | grep -q $$CONTAINER_ID; then \
			echo "✓ Nginx started successfully"; \
			docker stop $$CONTAINER_ID > /dev/null; \
		else \
			echo "✗ Nginx failed to start"; \
			docker logs $$CONTAINER_ID; \
			exit 1; \
		fi
	@echo ""
	@echo "All tests passed! ✓"

run: build ## Build and run nginx container
	@echo "Starting nginx container..."
	docker run -d --name $(IMAGE_NAME) -p 80:80 $(IMAGE_NAME):latest
	@echo ""
	@echo "Nginx is running at http://localhost"
	@echo "View logs: make logs"
	@echo "Stop container: make stop"

logs: ## Show nginx logs
	docker logs -f $(IMAGE_NAME)

stop: ## Stop and remove the nginx container
	@echo "Stopping nginx container..."
	@docker stop $(IMAGE_NAME) 2>/dev/null || true
	@docker rm $(IMAGE_NAME) 2>/dev/null || true
	@echo "Container stopped and removed"

clean: stop ## Stop container and remove images
	@echo "Removing Docker images..."
	@docker rmi $(IMAGE_NAME):latest 2>/dev/null || true
	@echo "Removing Dockerfile..."
	@rm -f Dockerfile
	@echo "Cleanup complete"

remote-build: ## Build directly from GitHub repository
	@echo "Building from GitHub repository..."
	docker build --network host \
		--build-arg NGINX_FROM_IMAGE=nginx:$(NGINX_VERSION) \
		--build-arg ENABLED_MODULES=$(ENABLED_MODULES) \
		-t $(IMAGE_NAME):remote \
		'https://github.com/jee-r/docker-nginx-cachepurge.git#main'
	@echo "Remote build complete"

.DEFAULT_GOAL := help
