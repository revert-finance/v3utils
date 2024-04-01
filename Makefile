.PHONY = build test
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

CHAIN := ''
build: src/V3Utils.sol
	forge build
test: src/V3Utils.sol test/*
	forge test
deploy-%: 
	$(eval CHAIN=$(shell echo $* | tr '[:lower:]' '[:upper:]'))
	@echo CHAIN=$(CHAIN)
	@echo $(CHAIN)_GAS_PRICE=$($(CHAIN)_GAS_PRICE)
	@echo $(CHAIN)_RPC_URL=$($(CHAIN)_RPC_URL)
	forge script script/V3Utils.s.sol:MyScript --rpc-url $($(CHAIN)_RPC_URL) --broadcast