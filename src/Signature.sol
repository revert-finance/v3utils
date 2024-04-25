// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./EIP712.sol";
import "forge-std/console.sol";

abstract contract Signature is EIP712 {

    constructor(string memory name, string memory version) EIP712(name, version){}

    function _recover(Order memory order, bytes memory signature) internal view returns (address) {
        bytes32 digest = _hashTypedDataV4(_hash(order));
        return ECDSA.recover(digest, signature);
    }

    // keccak256(
    //     "AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportionX64,int256 feeToPrincipalRatioThresholdX64)"
    // );
    bytes32 constant AutoCompound_TYPEHASH = 0xc696e49b5b777ed39ec78fbfc2b42b9399d1edc7f3ea2bcf66b5d1fbd1e44ea8;
    struct AutoCompound {
        AutoCompoundAction action;
    }
    function _hash(AutoCompound memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            AutoCompound_TYPEHASH,
            _hash(obj.action)
        ));
    }

    // keccak256(
    //     "AutoCompoundAction(int256 maxGasProportionX64,int256 feeToPrincipalRatioThresholdX64)"
    // );
    bytes32 constant AutoCompoundAction_TYPEHASH = 0x3368609ed4d6c8bbf3f89c3340dfda10f6a3b6cbbf269a1ee1acab352e39d592;
    struct AutoCompoundAction {
        int256 maxGasProportionX64;
        int256 feeToPrincipalRatioThresholdX64;
    }
    function _hash(AutoCompoundAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            AutoCompoundAction_TYPEHASH,
            obj.maxGasProportionX64,
            obj.feeToPrincipalRatioThresholdX64
        ));
    }

    // keccak256(
    //     "TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)"
    // );
    bytes32 constant TickOffsetCondition_TYPEHASH = 0x62a0ad438254a5fc08168ddf3cb49a0b3c0e730e76f4fa785b4df532bc2dafb9;
    struct TickOffsetCondition {
        uint32 gteTickOffset;
        uint32 lteTickOffset;
    }
    function _hash(TickOffsetCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TickOffsetCondition_TYPEHASH,
            obj.gteTickOffset,
            obj.lteTickOffset
        ));
    }

    // keccak256(
    //     "PriceOffsetCondition(uint32 baseToken,uint256 gteOffsetSqrtPriceX96,uint256 lteOffsetSqrtPriceX96)"
    // );
    bytes32 constant PriceOffsetCondition_TYPEHASH = 0xee7cf2600f91b8ddafa790dd184ce3c665f9dc116423525b336e1edac8e07e12;
    struct PriceOffsetCondition {
        uint32 baseToken;
        uint256 gteOffsetSqrtPriceX96;
        uint256 lteOffsetSqrtPriceX96;
    }
    function _hash(PriceOffsetCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PriceOffsetCondition_TYPEHASH,
            obj.baseToken,
            obj.gteOffsetSqrtPriceX96,
            obj.lteOffsetSqrtPriceX96
        ));
    }

    // keccak256(
    //     "TokenRatioCondition(int256 lteToken0RatioX64,int256 gteToken0RatioX64)"
    // );
    bytes32 constant TokenRatioCondition_TYPEHASH = 0x45ae7b1ead003f850829121834fe562edded567cc66a42e8315561c98a7735f9;
    struct TokenRatioCondition {
        int256 lteToken0RatioX64;
        int256 gteToken0RatioX64;
    }
    function _hash(TokenRatioCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TokenRatioCondition_TYPEHASH,
            obj.lteToken0RatioX64,
            obj.gteToken0RatioX64
        ));
    }

    // keccak256(
    //     "RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)PriceOffsetCondition(uint32 baseToken,uint256 gteOffsetSqrtPriceX96,uint256 lteOffsetSqrtPriceX96)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioCondition(int256 lteToken0RatioX64,int256 gteToken0RatioX64)"
    // );
    bytes32 constant RebalanceCondition_TYPEHASH = 0x79a6efb57bb0d511e670abb964181b04730ebe3a5fd187d05341eeb9288deef8;
    struct RebalanceCondition {
        string _type;
        int160 sqrtPriceX96;
        int64 timeBuffer;
        TickOffsetCondition tickOffsetCondition;
        PriceOffsetCondition priceOffsetCondition;
        TokenRatioCondition tokenRatioCondition;
    }
    function _hash(RebalanceCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RebalanceCondition_TYPEHASH,
            keccak256(bytes(obj._type)),
            obj.sqrtPriceX96,
            obj.timeBuffer,
            _hash(obj.tickOffsetCondition),
            _hash(obj.priceOffsetCondition),
            _hash(obj.tokenRatioCondition)
        ));
    }

    // keccak256(
    //     "TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)"
    // );
    bytes32 constant TickOffsetAction_TYPEHASH = 0xf5f25bd65589108507b815014b323a5f159027eba9a477039a198a5f7fc368fc;
    struct TickOffsetAction {
        uint32 tickLowerOffset;
        uint32 tickUpperOffset;
    }
    function _hash(TickOffsetAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TickOffsetAction_TYPEHASH,
            obj.tickLowerOffset,
            obj.tickUpperOffset
        ));
    }

    // keccak256(
    //     "PriceOffsetAction(uint32 baseToken,int160 lowerOffsetSqrtPriceX96,int160 upperOffsetSqrtPriceX96)"
    // );
    bytes32 constant PriceOffsetAction_TYPEHASH = 0x0a6de33fb4ce9e036ea5aa72e73288d926400e8cc438f63c7c1c84b392c5801c;
    struct PriceOffsetAction {
        uint32 baseToken;
        int160 lowerOffsetSqrtPriceX96;
        int160 upperOffsetSqrtPriceX96;
    }
    function _hash(PriceOffsetAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PriceOffsetAction_TYPEHASH,
            obj.baseToken,
            obj.lowerOffsetSqrtPriceX96,
            obj.upperOffsetSqrtPriceX96
        ));
    }

    // keccak256(
    //     "TokenRatioAction(uint32 tickWidth,int256 token0RatioX64)"
    // );
    bytes32 constant TokenRatioAction_TYPEHASH = 0x2d91584261cab64f66268846e106be0b9e325f19b0457d3be9790bff2e4d9259;
    struct TokenRatioAction {
        uint32 tickWidth;
        int256 token0RatioX64;
    }
    function _hash(TokenRatioAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TokenRatioAction_TYPEHASH,
            obj.tickWidth,
            obj.token0RatioX64
        ));
    }

    // keccak256(
    //     "RebalanceAction(int256 maxGasProportionX64,int256 swapSlippageX64,int256 liquiditySlippageX64,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)PriceOffsetAction(uint32 baseToken,int160 lowerOffsetSqrtPriceX96,int160 upperOffsetSqrtPriceX96)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TokenRatioAction(uint32 tickWidth,int256 token0RatioX64)"
    // );
    bytes32 constant RebalanceAction_TYPEHASH = 0xe862ada4db7ad1d390d5445cf9eae9093553a68a1c33bdc043a9b9868c555579;
    struct RebalanceAction {
        int256 maxGasProportionX64;
        int256 swapSlippageX64;
        int256 liquiditySlippageX64;
        string _type;
        TickOffsetAction tickOffsetAction;
        PriceOffsetAction priceOffsetAction;
        TokenRatioAction tokenRatioAction;
    }
    function _hash(RebalanceAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RebalanceAction_TYPEHASH,
            obj.maxGasProportionX64,
            obj.swapSlippageX64,
            obj.liquiditySlippageX64,
            keccak256(bytes(obj._type)),
            _hash(obj.tickOffsetAction),
            _hash(obj.priceOffsetAction),
            _hash(obj.tokenRatioAction)
        ));
    }

    // keccak256(
    //     "RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportionX64,int256 feeToPrincipalRatioThresholdX64)PriceOffsetAction(uint32 baseToken,int160 lowerOffsetSqrtPriceX96,int160 upperOffsetSqrtPriceX96)PriceOffsetCondition(uint32 baseToken,uint256 gteOffsetSqrtPriceX96,uint256 lteOffsetSqrtPriceX96)RebalanceAction(int256 maxGasProportionX64,int256 swapSlippageX64,int256 liquiditySlippageX64,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,int256 token0RatioX64)TokenRatioCondition(int256 lteToken0RatioX64,int256 gteToken0RatioX64)"
    // );
    bytes32 constant RebalanceConfig_TYPEHASH = 0xf415885b16dd99154167dc3471d942b4653222ee365743f5e7f22f0f11f6b37c;
    struct RebalanceConfig {
        RebalanceCondition rebalanceCondition;
        RebalanceAction rebalanceAction;
        AutoCompound autoCompound;
        bool recurring;
    }
    function _hash(RebalanceConfig memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RebalanceConfig_TYPEHASH,
            _hash(obj.rebalanceCondition),
            _hash(obj.rebalanceAction),
            _hash(obj.autoCompound),
            obj.recurring
        ));
    }

    // keccak256(
    //     "RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)"
    // );
    bytes32 constant RangeOrderCondition_TYPEHASH = 0xb6800e34595dae872617c5005f10a6a9e2b6a2520654db474bf4750fdd70a0c8;
    struct RangeOrderCondition {
        bool zeroToOne;
        int32 gteTickAbsolute;
        int32 lteTickAbsolute;
    }
    function _hash(RangeOrderCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RangeOrderCondition_TYPEHASH,
            obj.zeroToOne,
            obj.gteTickAbsolute,
            obj.lteTickAbsolute
        ));
    }

    // keccak256(
    //     "RangeOrderAction(int256 maxGasProportionX64,int256 swapSlippageX64,int256 withdrawSlippageX64)"
    // );
    bytes32 constant RangeOrderAction_TYPEHASH = 0xf512215c27c5930c08d4f9d3f8d89d9b5735fb786bebf2231b3e88df5c4015d9;
    struct RangeOrderAction {
        int256 maxGasProportionX64;
        int256 swapSlippageX64;
        int256 withdrawSlippageX64;
    }
    function _hash(RangeOrderAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RangeOrderAction_TYPEHASH,
            obj.maxGasProportionX64,
            obj.swapSlippageX64,
            obj.withdrawSlippageX64
        ));
    }

    // keccak256(
    //     "RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RangeOrderAction(int256 maxGasProportionX64,int256 swapSlippageX64,int256 withdrawSlippageX64)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)"
    // );
    bytes32 constant RangeOrderConfig_TYPEHASH = 0x896dec1198540e9a29dda867832b7bb119f2cec50527c0f5ee63ef305b0f539a;
    struct RangeOrderConfig {
        RangeOrderCondition condition;
        RangeOrderAction action;
    }
    function _hash(RangeOrderConfig memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RangeOrderConfig_TYPEHASH,
            _hash(obj.condition),
            _hash(obj.action)
        ));
    }

    // keccak256(
    //     "OrderConfig(RebalanceConfig rebalanceConfig,RangeOrderConfig rangeOrderConfig)AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportionX64,int256 feeToPrincipalRatioThresholdX64)PriceOffsetAction(uint32 baseToken,int160 lowerOffsetSqrtPriceX96,int160 upperOffsetSqrtPriceX96)PriceOffsetCondition(uint32 baseToken,uint256 gteOffsetSqrtPriceX96,uint256 lteOffsetSqrtPriceX96)RangeOrderAction(int256 maxGasProportionX64,int256 swapSlippageX64,int256 withdrawSlippageX64)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RebalanceAction(int256 maxGasProportionX64,int256 swapSlippageX64,int256 liquiditySlippageX64,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,int256 token0RatioX64)TokenRatioCondition(int256 lteToken0RatioX64,int256 gteToken0RatioX64)"
    // );
    bytes32 constant OrderConfig_TYPEHASH = 0x065b4cd96c3232169bffd05f96758c6381c4797dce4724b29ca398f302c8d58a;
    struct OrderConfig {
        RebalanceConfig rebalanceConfig;
        RangeOrderConfig rangeOrderConfig;
    }
    function _hash(OrderConfig memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OrderConfig_TYPEHASH,
            _hash(obj.rebalanceConfig),
            _hash(obj.rangeOrderConfig)
        ));
    }

    // keccak256(
    //     "Order(int64 chainId,address nfpmAddress,uint256 tokenId,string orderType,OrderConfig config,int64 signatureTime)AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportionX64,int256 feeToPrincipalRatioThresholdX64)OrderConfig(RebalanceConfig rebalanceConfig,RangeOrderConfig rangeOrderConfig)PriceOffsetAction(uint32 baseToken,int160 lowerOffsetSqrtPriceX96,int160 upperOffsetSqrtPriceX96)PriceOffsetCondition(uint32 baseToken,uint256 gteOffsetSqrtPriceX96,uint256 lteOffsetSqrtPriceX96)RangeOrderAction(int256 maxGasProportionX64,int256 swapSlippageX64,int256 withdrawSlippageX64)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RebalanceAction(int256 maxGasProportionX64,int256 swapSlippageX64,int256 liquiditySlippageX64,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,int256 token0RatioX64)TokenRatioCondition(int256 lteToken0RatioX64,int256 gteToken0RatioX64)"
    // );
    bytes32 constant Order_TYPEHASH = 0x8201e8c31784c3b8b26a36edc724801769c61b18d1a75e21a780d4bf1ad29272;
    struct Order {
        int64 chainId;
        address nfpmAddress;
        uint256 tokenId;
        string orderType;
        OrderConfig config;
        int64 signatureTime;
    }
    function _hash(Order memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            Order_TYPEHASH,
            obj.chainId,
            obj.nfpmAddress,
            obj.tokenId,
            keccak256(bytes(obj.orderType)),
            _hash(obj.config),
            obj.signatureTime
        ));
    }
}