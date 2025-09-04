# Foundry NFT Project Makefile
# This file contains common commands for building, testing, and deploying

# Default target
.DEFAULT_GOAL := help

# Variables
NETWORK ?= sepolia
ETHERSCAN_API_KEY ?= 
RPC_URL ?= 

# Colors for output
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

##@ Building

build: ## Build the project
	@echo "$(GREEN)Building project...$(RESET)"
	forge build

clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning build artifacts...$(RESET)"
	forge clean

install: ## Install dependencies
	@echo "$(GREEN)Installing dependencies...$(RESET)"
	forge install OpenZeppelin/openzeppelin-contracts
	forge install foundry-rs/forge-std

##@ Testing

test: ## Run all tests
	@echo "$(GREEN)Running tests...$(RESET)"
	forge test -vv

test-verbose: ## Run tests with maximum verbosity
	@echo "$(GREEN)Running tests with verbose output...$(RESET)"
	forge test -vvvv

test-gas: ## Run tests with gas reporting
	@echo "$(GREEN)Running tests with gas reporting...$(RESET)"
	forge test --gas-report

test-coverage: ## Run test coverage
	@echo "$(GREEN)Generating coverage report...$(RESET)"
	forge coverage

test-coverage-html: ## Generate HTML coverage report
	@echo "$(GREEN)Generating HTML coverage report...$(RESET)"
	forge coverage --report lcov
	genhtml lcov.info -o coverage-html
	@echo "$(GREEN)Coverage report generated in coverage-html/$(RESET)"

test-fuzz: ## Run fuzzing tests with more iterations
	@echo "$(GREEN)Running extensive fuzz tests...$(RESET)"
	forge test --fuzz-runs 10000

test-specific: ## Run specific test (usage: make test-specific TEST=testName)
	@echo "$(GREEN)Running specific test: $(TEST)$(RESET)"
	forge test --match-test $(TEST) -vv

##@ Formatting and Linting

fmt: ## Format code
	@echo "$(GREEN)Formatting code...$(RESET)"
	forge fmt

fmt-check: ## Check code formatting
	@echo "$(YELLOW)Checking code formatting...$(RESET)"
	forge fmt --check

##@ Deployment

deploy-local: ## Deploy to local testnet
	@echo "$(GREEN)Deploying to local network...$(RESET)"
	forge script script/DeployScript.s.sol:DeployScript --fork-url http://localhost:8545 --broadcast

deploy-testnet: ## Deploy to testnet (specify NETWORK)
	@echo "$(GREEN)Deploying to $(NETWORK)...$(RESET)"
	forge script script/Deploy.s.sol:DeployScript --rpc-url $(RPC_URL) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

deploy-mainnet: ## Deploy to mainnet (BE CAREFUL!)
	@echo "$(RED)Deploying to MAINNET - Are you sure? (Ctrl+C to cancel)$(RESET)"
	@read -p "Press enter to continue..."
	forge script script/Deploy.s.sol:DeployScript --rpc-url $(RPC_URL) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

##@ Local Development

anvil: ## Start local Anvil node
	@echo "$(GREEN)Starting local Anvil node...$(RESET)"
	anvil

anvil-fork: ## Start Anvil forking mainnet (requires RPC_URL)
	@echo "$(GREEN)Starting Anvil fork from mainnet...$(RESET)"
	anvil --fork-url $(RPC_URL)

##@ Contract Interaction

verify: ## Verify contract on Etherscan (usage: make verify CONTRACT=0x... NETWORK=sepolia)
	@echo "$(GREEN)Verifying contract $(CONTRACT) on $(NETWORK)...$(RESET)"
	forge verify-contract $(CONTRACT) src/MyNFT.sol:MyNFT --etherscan-api-key $(ETHERSCAN_API_KEY) --chain $(NETWORK)

flatten: ## Flatten contract for verification
	@echo "$(GREEN)Flattening contract...$(RESET)"
	forge flatten src/MyNFT.sol > MyNFT_flattened.sol
	@echo "$(GREEN)Contract flattened to MyNFT_flattened.sol$(RESET)"

##@ Analysis

analyze: ## Run static analysis with slither (requires slither installation)
	@echo "$(GREEN)Running static analysis...$(RESET)"
	slither src/MyNFT.sol

gas-snapshot: ## Take gas snapshot
	@echo "$(GREEN)Taking gas snapshot...$(RESET)"
	forge snapshot

##@ Documentation

doc: ## Generate documentation
	@echo "$(GREEN)Generating documentation...$(RESET)"
	forge doc

doc-serve: ## Serve documentation locally
	@echo "$(GREEN)Serving documentation at http://localhost:3000$(RESET)"
	forge doc --serve --port 3000

##@ Utility

sizes: ## Check contract sizes
	@echo "$(GREEN)Checking contract sizes...$(RESET)"
	forge build --sizes

storage-layout: ## Show storage layout
	@echo "$(GREEN)Showing storage layout...$(RESET)"
	forge inspect MyNFT storage-layout

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $1, $2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($0, 5) } ' $(MAKEFILE_LIST)

.PHONY: build clean install test test-verbose test-gas test-coverage test-coverage-html test-fuzz test-specific fmt fmt-check deploy-local deploy-testnet deploy-mainnet anvil anvil-fork verify flatten analyze gas-snapshot doc doc-serve sizes storage-layout help