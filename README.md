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

# Remember to check smart wallet address
# Deploy
```
source .env
forge script script/V3Utils.s.sol:MyScript --legacy --rpc-url $RPC_URL --broadcast
```
using `--with-gas-price` flag to sepecify gas price:
```
forge script script/V3Utils.s.sol:MyScript --legacy --rpc-url $RPC_URL --broadcast --with-gas-price $GAS_PRICE
```
or with Makefile:
```
make deploy-v3utils
```
# Verify Contract

Run script below to get verify contract script
```
make verify-v3utils
```