// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/Signature.sol";
import "forge-std/Test.sol";

contract Temp is Signature {
    constructor(string memory name, string memory version) Signature(name, version){}
}

contract SignatureTest is Test {
    function setUp() external {}
    function testSignature() external {
        Temp t = new Temp("", "");
        bytes32 DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("V3AutomationOrder")),
            keccak256(bytes("1.0")),
            42161,
            address(0)
        ));
        Signature.Order memory order = _fillOrderData();
        bytes memory signature = hex"826c039687b2e80e15a3e2113676083a6cf78eeadde9404bd4303c6eeb051fa131763fbda53f2bc22cdc5a4b16b0213f73bb2a992195d4ba331671965698ea3a1c";
        
        bytes32 digest = MessageHashUtils.toTypedDataHash(DOMAIN_SEPARATOR, t.hashOrder(order));
        address user = ECDSA.recover(digest, signature);
        assertEq(user, 0x04Ff397401AF494d68848FCaa4c78dCa785d33FC);
    }

    function _fillOrderData() internal pure returns (Signature.Order memory) {
        return Signature.Order({
            chainId: 1,
            nfpmAddress: 0x1234567890123456789012345678901234567890,
            tokenId: 123,
            orderType: "YourOrderType",
            config: Signature.OrderConfig({
                rebalanceConfig: Signature.RebalanceConfig({
                    rebalanceCondition: Signature.RebalanceCondition({
                        _type: "YourRebalanceType",
                        sqrtPriceX96: 123456,
                        timeBuffer: 1234567890,
                        tickOffsetCondition: Signature.TickOffsetCondition({
                            gteTickOffset: 123,
                            lteTickOffset: 456
                        }),
                        priceOffsetCondition: Signature.PriceOffsetCondition({
                            baseToken: 789,
                            gtePriceOffset: 123456789,
                            ltePriceOffset: 987654321
                        }),
                        tokenRatioCondition: Signature.TokenRatioCondition({
                            lteToken0Ratio: 123456789,
                            gteToken0Ratio: 987654321
                        })
                    }),
                    rebalanceAction: Signature.RebalanceAction({
                        maxGasProportion: 123456789,
                        swapSlippage: 123456789,
                        liquiditySlippage: 123456789,
                        _type: "YourRebalanceActionType",
                        tickOffsetAction: Signature.TickOffsetAction({
                            tickLowerOffset: 123,
                            tickUpperOffset: 456
                        }),
                        priceOffsetAction: Signature.PriceOffsetAction({
                            baseToken: 789,
                            priceLowerOffset: 123456,
                            priceUpperOffset: 654321
                        }),
                        tokenRatioAction: Signature.TokenRatioAction({
                            tickWidth: 123,
                            token0Ratio: 987654321
                        })
                    }),
                    autoCompound: Signature.AutoCompound({
                        action: Signature.AutoCompoundAction({
                            maxGasProportion: 123456789,
                            feeToPrincipalRatioThreshold: 987654321
                        })
                    }),
                    recurring: true
                }),
                rangeOrderConfig: Signature.RangeOrderConfig({
                    condition: Signature.RangeOrderCondition({
                        zeroToOne: true,
                        gteTickAbsolute: 123,
                        lteTickAbsolute: 456
                    }),
                    action: Signature.RangeOrderAction({
                        maxGasProportion: 123456789,
                        swapSlippage: 123456789,
                        withdrawSlippage: 123456789
                    })
                })
            }),
            signatureTime: 1234567890
        });
    }
}