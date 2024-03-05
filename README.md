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



## Deployment for Pancakeswap

There need to be done some minimal changes to the code and linked library interfaces.


Change POOL_INIT_CODE_HASH in PoolAddress.sol to

```
bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
```

IUniswapV3PoolState change slot0() function to this (note the uint32 for feeProtocol)

```
function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint32 feeProtocol,
            bool unlocked
        );
```

Add this function to IPeripheryImmutableState

```
function deployer() external view returns (address);
```

Automator.sol


Add to storage variables:
```
address private immutable deployer;
```

Add to constructor:
```
deployer = npm.deployer();
```

Change method:
```
// get pool for token
function _getPool(
    address tokenA,
    address tokenB,
    uint24 fee
) internal view returns (IUniswapV3Pool) {
    return
        IUniswapV3Pool(
            PoolAddress.computeAddress(
                deployer,
                PoolAddress.getPoolKey(tokenA, tokenB, fee)
            )
        );
}
```