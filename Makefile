-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil remixed

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

install :; \
    forge install foundry-rs/forge-std@v1.7.6 --no-commit && \
    forge install openzeppelin/openzeppelin-contracts@v5.0.2 --no-commit && \
    forge install openzeppelin/openzeppelin-contracts-upgradeable@v5.0.2 --no-commit && \
    forge install cyfrin/foundry-devops@0.0.11 --no-commit

build :; forge build --extra-output-files abi

anvil :; anvil --block-time 10

testm :; forge test --mt $(m) -vvvv

coverage :; forge coverage --report debug > coverage-report.txt

remixd :; \
	forge build --extra-output-files abi && \
	cp ./out/MSC20MarketV1.sol/MSC20MarketV1.abi.json ./remixd/MSC20MarketV1.abi && \
	remixd -s ./remixd  

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast --legacy

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployMSC20MarketV1.s.sol:DeployMSC20MarketV1 $(NETWORK_ARGS) 

# 生成go合约代码，c = 合约名称, 
abigen:
	@forge build --extra-output-files abi bin
	@abigen --bin=out/$(c).sol/$(c).bin --abi=out/$(c).sol/$(c).abi.json --pkg=store --out=go/$(c).go

