.PHONY = build test
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

build: src/V3Utils.sol
	forge build
test: src/V3Utils.sol test/*
	forge test
deploy-v3utils-%: 
	$(eval CHAIN=$(shell echo $* | tr '[:lower:]' '[:upper:]'))
	@echo CHAIN=$(CHAIN)
	@echo RPC_URL=$(RPC_URL)
	forge script script/V3Utils.s.sol:V3UtilsScript --rpc-url $(RPC_URL) --broadcast

deploy-v3auto-%: 
	$(eval CHAIN=$(shell echo $* | tr '[:lower:]' '[:upper:]'))
	@echo CHAIN=$(CHAIN)
	@echo RPC_URL=$(RPC_URL)
	forge script script/V3Automation.s.sol:V3AutomationScript --rpc-url $(RPC_URL) --legacy --broadcast

env-%:
	$(eval ENV=$(shell echo $* | tr '[:lower:]' '[:upper:]'))
    @ ifeq ($(ENV),) \
		$(error ENV $(ENV) is not set) \
	endif