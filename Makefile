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
deploy-v3utils-%: 
	$(eval CHAIN=$(shell echo $* | tr '[:lower:]' '[:upper:]'))
	@echo CHAIN=$(CHAIN)
	@echo $(CHAIN)_RPC_URL=$($(CHAIN)_RPC_URL)
	forge script script/V3Utils.s.sol:V3UtilsScript --rpc-url $($(CHAIN)_RPC_URL) --broadcast

deploy-v3auto-%: 
	$(eval CHAIN=$(shell echo $* | tr '[:lower:]' '[:upper:]'))
	@echo CHAIN=$(CHAIN)
	@echo $(CHAIN)_RPC_URL=$($(CHAIN)_RPC_URL)
	forge script script/V3Automation.s.sol:V3AutomationScript --rpc-url $($(CHAIN)_RPC_URL) --legacy --broadcast