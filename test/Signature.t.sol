// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/Signature.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract SignatureTest is Test {
    function setUp() external {}
    function testSignature() external {
        Signature sigContract = new Signature(Signature.EIP712Domain(
            "V3AutomationOrder",
            "1.0",
            42161,
            address(0)
        ));
        // console.logBytes32(sigContract.DOMAIN_SEPARATOR);
        Signature.Order memory order = Signature.Order(
            42161,
            0xC36442b4a4522E871399CD717aBDD847Ab11FE88,
            "1452442",
            "ORDER_TYPE_REBALANCE",
            _fillOrderConfig()
        );
        bytes memory signature = hex"ffa7b62d6b6d1965388dc9532d8c50f8d08a11c4930360f45551e789fb1b51091988f3e3914a8ea10b2d97f2ed2e5abbb9824724fa87d81a0f02bc0c74c9fd8c1b";
        address user = sigContract.recover(order, signature);
        console.log(user);
    }

    function _fillOrderConfig() internal pure returns (Signature.OrderConfig memory) {
        return Signature.OrderConfig(
            Signature.RebalanceConfig(
                Signature.RebalanceCondition(
                    "CONDITION_TYPE_PERCENTAGE",
                    "4493229508969825186401995",
                    0,
                    Signature.TickOffsetCondition(13, 21),
                    Signature.PriceOffsetCondition(0, "", ""),
                    Signature.TokenRatioCondition("", "")
                ),
                Signature.RebalanceAction(
                    "0.05",
                    "0.01",
                    "0.01",
                    "ACTION_TYPE_PERCENTAGE",
                    Signature.TickOffsetAction(59, 107),
                    Signature.PriceOffsetAction(0, "", ""),
                    Signature.TokenRatioAction(0, "")
                ),
                Signature.AutoCompound(
                    Signature.AutoCompoundAction("0.05", "0.05")
                ),
                true
            ),
            Signature.RangeOrderConfig(
                Signature.RangeOrderCondition(false, 0, 0),
                Signature.RangeOrderAction("", "", "")
            )
        );
    }
}