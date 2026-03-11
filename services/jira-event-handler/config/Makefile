MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SERVICE_ROOT := $(abspath $(MAKEFILE_DIR)/..)

.PHONY: install test build clean package deploy

install:
	pip install -r $(MAKEFILE_DIR)/requirements.txt

test:
	pytest $(SERVICE_ROOT)/tests -v --cov=$(SERVICE_ROOT)/src

build:
	rm -rf $(SERVICE_ROOT)/build $(SERVICE_ROOT)/dist $(SERVICE_ROOT)/*.egg-info
	mkdir -p $(SERVICE_ROOT)/build
	cp -r $(SERVICE_ROOT)/src/* $(SERVICE_ROOT)/build/
	cd $(SERVICE_ROOT)/build && zip -r ../jira-handler.zip . && cd ..
	rm -rf $(SERVICE_ROOT)/build/

clean:
	rm -rf $(SERVICE_ROOT)/build $(SERVICE_ROOT)/dist $(SERVICE_ROOT)/*.egg-info $(SERVICE_ROOT)/__pycache__ $(SERVICE_ROOT)/.pytest_cache $(SERVICE_ROOT)/.coverage $(SERVICE_ROOT)/htmlcov $(SERVICE_ROOT)/*.zip
	find $(SERVICE_ROOT) -type d -name __pycache__ -exec rm -rf {} +

package: clean build

deploy: package
	@echo "Deploy jira-handler.zip to AWS Lambda"
	aws lambda update-function-code --function-name devops-platform-jira-event-handler --zip-file fileb://$(SERVICE_ROOT)/jira-handler.zip

help:
	@echo "Available targets:"
	@echo "  make install   - Install dependencies"
	@echo "  make test      - Run tests"
	@echo "  make build     - Build lambda package"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make package   - Clean and build"
	@echo "  make deploy    - Deploy to AWS Lambda"
