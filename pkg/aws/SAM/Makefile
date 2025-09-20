.PHONY: help build deploy deploy-dev deploy-staging deploy-prod clean test validate local-api

# Default environment
ENV ?= dev
REGION ?= us-east-1

help: ## Show this help message
	@echo "AutoSpotter Web Client - SAM Deployment"
	@echo ""
	@echo "Usage: make [target] [ENV=environment] [REGION=region]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make deploy ENV=dev"
	@echo "  make deploy-staging"
	@echo "  make clean"

validate: ## Validate SAM template
	@echo "🔍 Validating SAM template..."
	sam validate

build: validate ## Build SAM application
	@echo "📦 Building SAM application..."
	sam build

test: ## Run tests
	@echo "🧪 Running tests..."
	@if [ -d "../web" ] && [ -f "../web/package.json" ]; then \
		cd ../web && npm test; \
	else \
		echo "No web client found to test"; \
	fi

build-web: ## Build web client
	@echo "🌐 Building web client..."
	@if [ -d "../web" ] && [ -f "../web/package.json" ]; then \
		cd ../web && npm install && npm run build; \
	else \
		echo "❌ No web client found. Please set up the web client first."; \
		exit 1; \
	fi

deploy: build build-web ## Deploy to specified environment (default: dev)
	@echo "🚀 Deploying to $(ENV) environment..."
	@if [ "$(ENV)" = "dev" ]; then \
		sam deploy --config-env default --parameter-overrides "Environment=$(ENV)"; \
	else \
		sam deploy --config-env $(ENV) --parameter-overrides "Environment=$(ENV)"; \
	fi
	@$(MAKE) sync-assets ENV=$(ENV)

deploy-dev: ENV=dev
deploy-dev: deploy ## Deploy to development environment

deploy-staging: ENV=staging
deploy-staging: deploy ## Deploy to staging environment

deploy-prod: ENV=prod
deploy-prod: deploy ## Deploy to production environment

sync-assets: ## Sync web assets to S3
	@echo "📤 Syncing web assets to S3..."
	@STACK_NAME=$$(if [ "$(ENV)" = "dev" ]; then echo "autospotter-web"; else echo "autospotter-web-$(ENV)"; fi); \
	BUCKET_NAME=$$(aws cloudformation describe-stacks \
		--stack-name $$STACK_NAME \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[?OutputKey==`WebClientBucketName`].OutputValue' \
		--output text); \
	if [ "$$BUCKET_NAME" != "None" ] && [ -n "$$BUCKET_NAME" ]; then \
		aws s3 sync ../web/dist/ s3://$$BUCKET_NAME/ --delete --region $(REGION); \
		echo "✅ Assets synced to $$BUCKET_NAME"; \
	else \
		echo "❌ Could not retrieve S3 bucket name"; \
		exit 1; \
	fi

invalidate-cache: ## Invalidate CloudFront cache
	@echo "🔄 Invalidating CloudFront cache..."
	@STACK_NAME=$$(if [ "$(ENV)" = "dev" ]; then echo "autospotter-web"; else echo "autospotter-web-$(ENV)"; fi); \
	DISTRIBUTION_ID=$$(aws cloudformation describe-stacks \
		--stack-name $$STACK_NAME \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
		--output text); \
	if [ "$$DISTRIBUTION_ID" != "None" ] && [ -n "$$DISTRIBUTION_ID" ]; then \
		aws cloudfront create-invalidation \
			--distribution-id $$DISTRIBUTION_ID \
			--paths "/*" \
			--region $(REGION); \
		echo "✅ CloudFront cache invalidated"; \
	else \
		echo "⚠️  Could not retrieve CloudFront distribution ID"; \
	fi

local-api: build ## Start SAM local API
	@echo "🖥️  Starting local API..."
	sam local start-api --host 0.0.0.0 --port 3001

logs: ## Tail CloudWatch logs
	@STACK_NAME=$$(if [ "$(ENV)" = "dev" ]; then echo "autospotter-web"; else echo "autospotter-web-$(ENV)"; fi); \
	sam logs --stack-name $$STACK_NAME --tail

delete: ## Delete the stack (WARNING: This will destroy all resources)
	@echo "⚠️  WARNING: This will delete all resources in the $(ENV) environment!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		STACK_NAME=$$(if [ "$(ENV)" = "dev" ]; then echo "autospotter-web"; else echo "autospotter-web-$(ENV)"; fi); \
		aws cloudformation delete-stack --stack-name $$STACK_NAME --region $(REGION); \
		echo "🗑️  Stack deletion initiated"; \
	else \
		echo "❌ Stack deletion cancelled"; \
	fi

clean: ## Clean build artifacts
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf .aws-sam/
	@if [ -d "../web/dist" ]; then rm -rf ../web/dist/; fi
	@if [ -d "../web/node_modules/.cache" ]; then rm -rf ../web/node_modules/.cache/; fi

status: ## Show stack status
	@STACK_NAME=$$(if [ "$(ENV)" = "dev" ]; then echo "autospotter-web"; else echo "autospotter-web-$(ENV)"; fi); \
	aws cloudformation describe-stacks \
		--stack-name $$STACK_NAME \
		--region $(REGION) \
		--query 'Stacks[0].{StackName:StackName,Status:StackStatus,LastUpdated:LastUpdatedTime}' \
		--output table

outputs: ## Show stack outputs
	@STACK_NAME=$$(if [ "$(ENV)" = "dev" ]; then echo "autospotter-web"; else echo "autospotter-web-$(ENV)"; fi); \
	aws cloudformation describe-stacks \
		--stack-name $$STACK_NAME \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[]' \
		--output table

# Development helpers
watch: ## Watch for changes and redeploy (requires sam cli with sync)
	@echo "👀 Watching for changes..."
	sam sync --config-env $(ENV) --watch

init-web: ## Initialize web client project
	@echo "🌐 Initializing web client..."
	@if [ ! -d "../web" ]; then \
		mkdir -p ../web; \
		cd ../web && npm init -y; \
		echo "✅ Web client directory created. Please set up your React/Vue/etc project."; \
	else \
		echo "⚠️  Web client directory already exists"; \
	fi