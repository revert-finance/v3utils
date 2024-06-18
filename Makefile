ifneq (,$(wildcard ./.env))
    include .env
    export
endif
build: src/V3Utils.sol clean
	forge build
test: src/V3Utils.sol test/*
	forge test
.PHONY: clean
clean:
	forge clean && rm -rf cache
v3utils:
	$(eval CONTRACT=V3Utils)
v3automation:
	$(eval CONTRACT=V3Automation)
deploy-v3utils:
deploy-v3automation:
deploy-%: %
	forge script script/$(CONTRACT).s.sol:$(CONTRACT)Script --rpc-url $(RPC_URL) --broadcast
verify-v3utils:
verify-v3automation:
verify-%: %
	forge script script/Verify.s.sol:Verify$(CONTRACT)Script | awk 'END{print}' | bash
init-v3utils:
init-v3automation:
init-%: %
	forge script script/Init.s.sol:$(CONTRACT)InitializeScript --rpc-url $(RPC_URL) --broadcast
