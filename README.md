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
```

Polygon
```
forge script script/V3Utils.s.sol:MyScript --legacy --with-gas-price 80000000000 --rpc-url $POLYGON_RPC_URL --broadcast
```

Arbitrum
```
forge script script/V3Utils.s.sol:MyScript --legacy --with-gas-price 100000000 --rpc-url $ARBITRUM_RPC_URL --broadcast
```

Bsc
```
forge script script/V3Utils.s.sol:MyScript --rpc-url $BSC_RPC_URL --broadcast
```

# Verify Contract

Polygon
```
forge verify-contract --chain-id 137 --etherscan-api-key $POLYGONSCAN_API_KEY --verifier-url https://api.polygonscan.com/api/ 0xC1De096310E565b94e88DB80C0037597bcD7b46c src/V3Utils.sol:V3Utils --constructor-args $(cast abi-encode "constructor(address)" "0x70270C228c5B4279d1578799926873aa72446CcD")
```

Arbitrum
```
forge verify-contract --chain-id 42161 --etherscan-api-key $ARBISCAN_API_KEY --verifier-url https://api.arbiscan.io/api/ 0x1e976e2BFEDE112174B23Aaf8BdB762d608a4dAD src/V3Utils.sol:V3Utils --constructor-args $(cast abi-encode "constructor(address)" "0x864F01c5E46b0712643B956BcA607bF883e0dbC5")
```

Bsc
```
forge verify-contract --chain-id 56 --etherscan-api-key $BSCSCAN_API_KEY --verifier-url https://api.bscscan.com/api/ 0x751271ceb69C48bb7dB9BE16171f3EbD86c12ae2 src/V3Utils.sol:V3Utils --constructor-args $(cast abi-encode "constructor(address)" "0x051DC16b2ECB366984d1074dCC07c342a9463999")
```

