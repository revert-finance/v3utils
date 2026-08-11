# revert v3utils

This repository contains the smart contracts for revert v3utils.

It uses Foundry as development toolchain.

## EkuboUtils

`src/EkuboUtils.sol` provides the V3Utils-style position action surface for Ekubo's canonical Ethereum deployment:

- swap and mint a new position;
- swap and add liquidity while temporarily holding an existing NFT;
- collect and compound all fees;
- fully withdraw and optionally swap to one asset; and
- move range by fully emptying the old range and minting a replacement NFT.

The contract intentionally supports only extension-free concentrated-liquidity pools. Ekubo extensions and stableswap pools are rejected. A move-range operation must withdraw the complete old range; the original empty NFT is returned to its owner and the replacement NFT is sent to the requested NFT recipient. This preserves a one-range-per-NFT history for downstream position tracking. Ekubo only exposes all-or-nothing fee collection, so instructions choose whether to collect all accrued fees rather than setting per-token fee caps.

Existing-position actions use temporary NFT custody. The owner calls the canonical Positions contract's four-argument `safeTransferFrom(owner, ekuboUtils, tokenId, abi.encode(instructions))`; `EkuboUtils` performs the requested action as the temporary owner and returns the original NFT before the callback completes. No NFT approval is created or left behind. The `execute` convenience function remains available when a prior one-token approval is preferred, and that approval is cleared by the NFT transfer.

ERC-20 allowances are still required when the action supplies new assets. Ekubo pool keys use `address(0)` for native ETH, which `EkuboUtils` represents as WETH at its public and swap boundaries. Existing-position actions therefore pull WETH and unwrap it internally when depositing into a native-token pool; newly created positions can also be funded with `msg.value`.

Swaps use the same 0x Swap API v2 AllowanceHolder flow as the active V3Utils2 and V4Utils deployments. Request the quote with the deployed `EkuboUtils` address as `taker`, pass `quote.transaction.data` directly as `swapData`, and use the quote's `minBuyAmount` as the operation's minimum output. The contract approves only its immutable AllowanceHolder, calls that same address, and clears the allowance after every successful swap.

The mainnet deployment script pins the addresses published with [Ekubo EVM contracts v3.2.0](https://github.com/EkuboProtocol/evm-contracts/releases/tag/v3.2.0):

- Core: `0x00000000000014aA86C5d3c41765bb24e11bd701`
- Positions: `0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D`
- 0x AllowanceHolder: `0x0000000000001fF3684f28c67538d4D072C22734`

### Ethereum mainnet deployment

- EkuboUtils: [`0x93E1b9729f745B3D450EB7CDd8085649AF405102`](https://etherscan.io/address/0x93E1b9729f745B3D450EB7CDd8085649AF405102)
- Deployment transaction: [`0xf557be76829604b0ee9f86187082c200de9f6db2d9cf85d87602967b927ac25a`](https://etherscan.io/tx/0xf557be76829604b0ee9f86187082c200de9f6db2d9cf85d87602967b927ac25a)
- Deployment block: `25727695`

The deployed utility is ownerless, but it has not been audited. Revert's Ekubo position-management actions remain disabled until an independent security review and the dedicated Ekubo action interface are complete.


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

The Ekubo mainnet-fork test requires `MAINNET_RPC_URL`:

```sh
MAINNET_RPC_URL=https://... forge test --via-ir --match-contract EkuboUtilsIntegrationTest
```


Because the v3-periphery library (Solidity v0.8 branch) in PoolAddress.sol has a different POOL_INIT_CODE_HASH than the one deployed on Mainnet this needs to be changed for the integration tests to work properly.

bytes32 internal constant POOL_INIT_CODE_HASH = 0xa598dd2fba360510c5a8f02f44423a4468e902df5857dbce3ca162a43a3a31ff;

needs to be changed to 

bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;



## Deployment for Pancakeswap

There need to be done some minimal changes to the code and linked library interfaces.


Change POOL_INIT_CODE_HASH in PoolAddress.sol to

```
bytes32 internal constant POOL_INIT_CODE_HASH = 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2;
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
