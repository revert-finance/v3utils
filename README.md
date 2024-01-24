# revert v3utils

This repository contains the smart contracts for revert v3utils.

It uses Foundry as development toolchain.


## Setup

Install foundry 

https://book.getfoundry.sh/getting-started/installation

Install dependencies

```sh
forge install
```


## Tests

Most tests use a forked state of Ethereum Mainnet. You can run all tests with: 

```sh
forge test --via-ir
```


Because the v3-periphery library (Solidity v0.8 branch) in PoolAddress.sol has a different POOL_INIT_CODE_HASH than the one deployed on Mainnet this needs to be changed for the integration tests to work properly.

bytes32 internal constant POOL_INIT_CODE_HASH = 0xa598dd2fba360510c5a8f02f44423a4468e902df5857dbce3ca162a43a3a31ff;

needs to be changed to 

bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

# Deploy
```
source .env
```

```
forge script script/V3Utils.s.sol:MyScript --rpc-url $POLYGON_RPC_URL --broadcast --verify -vvvv
```

# Verify Contract
```
forge verify-contract --chain-id 137 --etherscan-api-key $POLYGONSCAN_API_KEY --verifier-url https://api.polygonscan.com/api/ 0xF7216A27fd692fDBcBc84Fa3B7c9536206a679DF src/V3Utils.sol:V3Utils --constructor-args $(cast abi-encode "constructor(address,address)" "0xC36442b4a4522E871399CD717aBDD847Ab11FE88" "0x70270C228c5B4279d1578799926873aa72446CcD")
```

