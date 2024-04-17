ifneq (,$(wildcard ./.env))
    include .env
    export
endif

build: src/V3Utils.sol
	forge build
test: src/V3Utils.sol test/*
	forge test
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
	forge script script/Verify.s.sol:Verify$(CONTRACT)Script | awk 'END{print}' | xargs -I{} bash -c '{}'
