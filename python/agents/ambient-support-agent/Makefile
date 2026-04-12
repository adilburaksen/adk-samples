PROJECT_ID ?= $(shell gcloud config get-value project 2>/dev/null)
REGION ?= us-central1
SERVICE_NAME ?= ambient-support-agent
NOTIFICATION_EMAIL ?=

install:
	@command -v uv >/dev/null 2>&1 || { echo "uv is not installed. Installing uv..."; curl -LsSf https://astral.sh/uv/0.6.12/install.sh | sh; source $HOME/.local/bin/env; }
	uv sync

dev:
	uv run adk api_server --trigger_sources "pubsub" --allow_origins="*" .

playground:
	uv run adk web --port 8501 .

lint:
	uv run codespell support_agent/
	uv run ruff check support_agent/ --fix
	uv run ruff format support_agent/
	uv run mypy support_agent/

deploy:
	@if [ -z "$(PROJECT_ID)" ]; then \
		echo "Error: PROJECT_ID is not set."; \
		echo "Run: gcloud config set project <your-project-id>"; \
		exit 1; \
	fi
	@echo "Deploying to Cloud Run in project: $(PROJECT_ID)..."
	gcloud run deploy $(SERVICE_NAME) \
		--source=. \
		--project=$(PROJECT_ID) \
		--region=$(REGION) \
		--no-allow-unauthenticated \
		--set-env-vars="GOOGLE_GENAI_USE_VERTEXAI=TRUE,GOOGLE_CLOUD_PROJECT=$(PROJECT_ID),GOOGLE_CLOUD_LOCATION=$(REGION)"

infra:
	@if [ -z "$(PROJECT_ID)" ]; then \
		echo "Error: PROJECT_ID is not set."; \
		echo "Run: gcloud config set project <your-project-id>"; \
		exit 1; \
	fi
	@echo "Setting up infrastructure for project: $(PROJECT_ID)..."
	cd terraform && terraform init && terraform apply -auto-approve \
		-var=project_id=$(PROJECT_ID) \
		-var=region=$(REGION) \
		-var=service_name=$(SERVICE_NAME) \
		-var=notification_email=$(NOTIFICATION_EMAIL)
	@echo ""
	@echo "Infrastructure setup complete!"
	@echo "  Topic:     support-tickets"
	@echo "  Scheduler: support-daily-summary (daily 8:00 UTC)"
	@echo "  Alerts:    P0/P1 tickets → $(NOTIFICATION_EMAIL)"
	@echo ""
	@echo "Next: make test"

test:
	@if [ -z "$(PROJECT_ID)" ]; then \
		echo "Error: PROJECT_ID is not set."; \
		echo "Run: gcloud config set project <your-project-id>"; \
		exit 1; \
	fi
	@echo "Publishing test ticket..."
	gcloud pubsub topics publish support-tickets \
		--project=$(PROJECT_ID) \
		--message='{"subject":"Test ticket","body":"This is a test ticket from make test","customer":"Test User"}' \
		--attribute=source=make-test
	@echo ""
	@echo "Check Cloud Logging for results:"
	@echo "  gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=$(SERVICE_NAME)' --project=$(PROJECT_ID) --limit=5 --format='table(timestamp, textPayload)'"

clean:
	@if [ -z "$(PROJECT_ID)" ]; then \
		echo "Error: PROJECT_ID is not set."; \
		echo "Run: gcloud config set project <your-project-id>"; \
		exit 1; \
	fi
	@echo "Tearing down infrastructure..."
	cd terraform && terraform destroy -auto-approve \
		-var=project_id=$(PROJECT_ID) \
		-var=service_name=$(SERVICE_NAME) \
		-var=notification_email=$(NOTIFICATION_EMAIL)
	gcloud run services delete $(SERVICE_NAME) \
		--project=$(PROJECT_ID) \
		--region=$(REGION) \
		--quiet || true
	@echo "Cleanup complete."
