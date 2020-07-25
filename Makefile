.PHONY: all start setup

all: build-docker-image

build-docker-image: ## Builds the production Docker build-docker-image for multiple platforms
	docker buildx create --use
	docker buildx build --platform linux/amd64,linux/arm/v7,linux/arm64 . --file Dockerfile --tag hyzual/koel-dev:latest

dgoss-ci: ## Run goss tests on the production Docker image
	dgoss run hyzual/koel-dev:latest

setup: ## Init the DEV docker-compose stack
	docker exec -it koeldev php artisan koel:init

sync-music: ## Sync music from the /music volume with the database
	docker exec -it koeldev php artisan koel:sync -v

clear-cache: ## Clear caches that sometimes cause error 500
	docker exec -it koeldev php artisan cache:clear

see-logs: ## Tail -f laravel logs
	docker exec -it koeldev tail -f storage/logs/laravel.log

start: ## Build and start the DEV docker-compose stack
	docker-compose -f docker-compose.dev.yml up -d --build
	@echo "Go to http://localhost"

dgoss-dev: ## Run goss tests on the dev docker-compose stack
	dgoss run docker-koel_koel:latest

help: ## Display this help screen
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
