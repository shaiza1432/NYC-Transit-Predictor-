.DEFAULT_GOAL := help

PROJECT  := nyc-transit-predictor
COMPOSE  := docker compose
PYTHON   := python

# ────────────────────────────────────────────────────────────────────
.PHONY: help
help:  ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} \
	      /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ── Docker workflow ────────────────────────────────────────────────
.PHONY: build
build:  ## Build the Docker image
	$(COMPOSE) build

.PHONY: train
train:  ## Run the training pipeline inside Docker
	$(COMPOSE) run --rm pipeline

.PHONY: dashboard
dashboard:  ## Start the Streamlit dashboard (http://localhost:8501)
	$(COMPOSE) up -d dashboard
	@echo "Dashboard up at http://localhost:8501"

.PHONY: notebook
notebook:  ## Start the Jupyter dev container (http://localhost:8888)
	$(COMPOSE) --profile dev up -d notebook
	@echo "Notebook at http://localhost:8888"

.PHONY: logs
logs:  ## Tail dashboard logs
	$(COMPOSE) logs -f dashboard

.PHONY: down
down:  ## Stop and remove all containers
	$(COMPOSE) down

.PHONY: shell
shell:  ## Open a shell inside the dashboard container
	$(COMPOSE) run --rm dashboard bash

# ── Code quality (run on host or inside the dev container) ─────────
.PHONY: lint
lint:  ## Lint with ruff
	ruff check .

.PHONY: format
format:  ## Auto-format with ruff
	ruff format .

.PHONY: typecheck
typecheck:  ## Type-check with mypy
	mypy dashboard

.PHONY: test
test:  ## Run unit tests
	pytest -m "not slow" --cov=dashboard.src --cov-report=term-missing

.PHONY: test-integration
test-integration:  ## Run slow / integration tests
	pytest -m "integration"

.PHONY: test-all
test-all:  ## Run every test
	pytest

# ── Housekeeping ───────────────────────────────────────────────────
.PHONY: clean
clean:  ## Remove build artefacts, caches, logs, plots
	rm -rf models/rf_pipeline models/metrics.json
	rm -rf dashboard/static/plots/*.png
	rm -rf logs/*.log logs/*.zip
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type d -name .pytest_cache -prune -exec rm -rf {} +
	find . -type d -name .mypy_cache -prune -exec rm -rf {} +
	find . -type d -name .ruff_cache -prune -exec rm -rf {} +
