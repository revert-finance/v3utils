// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {EkuboUtils, IWETH9} from "../src/EkuboUtils.sol";
import {IEkuboPositions} from "../src/interfaces/IEkuboPositions.sol";

contract DeployEkuboUtils is Script {
    error EthereumMainnetOnly();

    IEkuboPositions internal constant POSITIONS = IEkuboPositions(0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D);
    address internal constant CORE = 0x00000000000014aA86C5d3c41765bb24e11bd701;
    IWETH9 internal constant WETH = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant ZERO_EX_ALLOWANCE_HOLDER = 0x0000000000001fF3684f28c67538d4D072C22734;

    function run() external returns (EkuboUtils deployed) {
        if (block.chainid != 1) revert EthereumMainnetOnly();

        vm.startBroadcast();
        deployed = new EkuboUtils(POSITIONS, CORE, WETH, ZERO_EX_ALLOWANCE_HOLDER);
        vm.stopBroadcast();
    }
}
