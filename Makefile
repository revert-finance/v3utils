.PHONY = build test V3Automation V3Utils
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

build: src/V3Utils.sol
	forge build
test: src/V3Utils.sol test/*
	forge test
deploy-v3utils: 
	forge script script/V3Utils.s.sol:V3UtilsScript --rpc-url $(RPC_URL) --broadcast
deploy-v3auto:
	forge script script/V3Automation.s.sol:V3AutomationScript --rpc-url $(RPC_URL) --legacy --broadcast
verify-v3utils:
	forge script script/Verify.s.sol:VerifyV3UtilsScript 
verify-v3automation:
	forge script script/Verify.s.sol:VerifyV3AutomationScript 