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
    //     "AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportion,int256 feeToPrincipalRatioThreshold)"
    // );
    bytes32 constant AutoCompound_TYPEHASH = 0x2ee4d79d0ae8e8b6f64966a8c7100aab7496ba6a711c7cd5d61a81b5c51c83fb;
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
    //     "AutoCompoundAction(int256 maxGasProportion,int256 feeToPrincipalRatioThreshold)"
    // );
    bytes32 constant AutoCompoundAction_TYPEHASH = 0x05f5822e2e885e621de1271ac17852e083bd1c94e947210e77316827ce0b660f;
    struct AutoCompoundAction {
        int256 maxGasProportion;
        int256 feeToPrincipalRatioThreshold;
    }
    function _hash(AutoCompoundAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            AutoCompoundAction_TYPEHASH,
            obj.maxGasProportion,
            obj.feeToPrincipalRatioThreshold
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
    //     "PriceOffsetCondition(uint32 baseToken,uint256 gtePriceOffset,uint256 ltePriceOffset)"
    // );
    bytes32 constant PriceOffsetCondition_TYPEHASH = 0x5cd9a332b74a67870bad2c6004af9794efc4345e3d4278485ef1a58dddca6c88;
    struct PriceOffsetCondition {
        uint32 baseToken;
        uint256 gtePriceOffset;
        uint256 ltePriceOffset;
    }
    function _hash(PriceOffsetCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PriceOffsetCondition_TYPEHASH,
            obj.baseToken,
            obj.gtePriceOffset,
            obj.ltePriceOffset
        ));
    }

    // keccak256(
    //     "TokenRatioCondition(int256 lteToken0Ratio,int256 gteToken0Ratio)"
    // );
    bytes32 constant TokenRatioCondition_TYPEHASH = 0x83e5c29f23e74206e866e6771777fc3ab544c6113755e8fd4aa0c3d6e749dbbb;
    struct TokenRatioCondition {
        int256 lteToken0Ratio;
        int256 gteToken0Ratio;
    }
    function _hash(TokenRatioCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TokenRatioCondition_TYPEHASH,
            obj.lteToken0Ratio,
            obj.gteToken0Ratio
        ));
    }

    // keccak256(
    //     "RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)PriceOffsetCondition(uint32 baseToken,uint256 gtePriceOffset,uint256 ltePriceOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioCondition(int256 lteToken0Ratio,int256 gteToken0Ratio)"
    // );
    bytes32 constant RebalanceCondition_TYPEHASH = 0x0c94e164cd0a5467d877f3eb040cc92c7d8d9115494ed377d36bb9be965af75e;
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
    //     "PriceOffsetAction(uint32 baseToken,int160 priceLowerOffset,int160 priceUpperOffset)"
    // );
    bytes32 constant PriceOffsetAction_TYPEHASH = 0x7f9b3234a3ed1996ca0b641f34c93677d8fa6d42c9a41ff0eccacb512d6ddee2;
    struct PriceOffsetAction {
        uint32 baseToken;
        int160 priceLowerOffset;
        int160 priceUpperOffset;
    }
    function _hash(PriceOffsetAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PriceOffsetAction_TYPEHASH,
            obj.baseToken,
            obj.priceLowerOffset,
            obj.priceUpperOffset
        ));
    }

    // keccak256(
    //     "TokenRatioAction(uint32 tickWidth,int256 token0Ratio)"
    // );
    bytes32 constant TokenRatioAction_TYPEHASH = 0x5c266855558e2f998f89919b2f51b644193dfc7554b195f877643493c427227c;
    struct TokenRatioAction {
        uint32 tickWidth;
        int256 token0Ratio;
    }
    function _hash(TokenRatioAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TokenRatioAction_TYPEHASH,
            obj.tickWidth,
            obj.token0Ratio
        ));
    }

    // keccak256(
    //     "RebalanceAction(int256 maxGasProportion,int256 swapSlippage,int256 liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)PriceOffsetAction(uint32 baseToken,int160 priceLowerOffset,int160 priceUpperOffset)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TokenRatioAction(uint32 tickWidth,int256 token0Ratio)"
    // );
    bytes32 constant RebalanceAction_TYPEHASH = 0xc3317dbcf06f32d532825cf7ae5019913b44d1176738bbc14642061966bea6ff;
    struct RebalanceAction {
        int256 maxGasProportion;
        int256 swapSlippage;
        int256 liquiditySlippage;
        string _type;
        TickOffsetAction tickOffsetAction;
        PriceOffsetAction priceOffsetAction;
        TokenRatioAction tokenRatioAction;
    }
    function _hash(RebalanceAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RebalanceAction_TYPEHASH,
            obj.maxGasProportion,
            obj.swapSlippage,
            obj.liquiditySlippage,
            keccak256(bytes(obj._type)),
            _hash(obj.tickOffsetAction),
            _hash(obj.priceOffsetAction),
            _hash(obj.tokenRatioAction)
        ));
    }

    // keccak256(
    //     "RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportion,int256 feeToPrincipalRatioThreshold)PriceOffsetAction(uint32 baseToken,int160 priceLowerOffset,int160 priceUpperOffset)PriceOffsetCondition(uint32 baseToken,uint256 gtePriceOffset,uint256 ltePriceOffset)RebalanceAction(int256 maxGasProportion,int256 swapSlippage,int256 liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,int256 token0Ratio)TokenRatioCondition(int256 lteToken0Ratio,int256 gteToken0Ratio)"
    // );
    bytes32 constant RebalanceConfig_TYPEHASH = 0x82e514f236719f614bbdf46637df02e3d7ecc639bb4d663a83b8ce22ec047343;
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
    //     "RangeOrderAction(int256 maxGasProportion,int256 swapSlippage,int256 withdrawSlippage)"
    // );
    bytes32 constant RangeOrderAction_TYPEHASH = 0x8f79ea1576d0de9056858068d900197d762fa98b63787a3f9e29b2213f74462a;
    struct RangeOrderAction {
        int256 maxGasProportion;
        int256 swapSlippage;
        int256 withdrawSlippage;
    }
    function _hash(RangeOrderAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RangeOrderAction_TYPEHASH,
            obj.maxGasProportion,
            obj.swapSlippage,
            obj.withdrawSlippage
        ));
    }

    // keccak256(
    //     "RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RangeOrderAction(int256 maxGasProportion,int256 swapSlippage,int256 withdrawSlippage)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)"
    // );
    bytes32 constant RangeOrderConfig_TYPEHASH = 0xc9f954d89ba5e83d11487e561d15b3921a36ece4eeb1a60e4029a981db5cda52;
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
    //     "OrderConfig(RebalanceConfig rebalanceConfig,RangeOrderConfig rangeOrderConfig)AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportion,int256 feeToPrincipalRatioThreshold)PriceOffsetAction(uint32 baseToken,int160 priceLowerOffset,int160 priceUpperOffset)PriceOffsetCondition(uint32 baseToken,uint256 gtePriceOffset,uint256 ltePriceOffset)RangeOrderAction(int256 maxGasProportion,int256 swapSlippage,int256 withdrawSlippage)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RebalanceAction(int256 maxGasProportion,int256 swapSlippage,int256 liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,int256 token0Ratio)TokenRatioCondition(int256 lteToken0Ratio,int256 gteToken0Ratio)"
    // );
    bytes32 constant OrderConfig_TYPEHASH = 0x2551c8c7c8a31d24a417e1c369ffeb0b79f88a04a1ba450b3ac0434439613a45;
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
    //     "Order(int64 chainId,address nfpmAddress,uint256 tokenId,string orderType,OrderConfig config,int64 signatureTime)AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportion,int256 feeToPrincipalRatioThreshold)OrderConfig(RebalanceConfig rebalanceConfig,RangeOrderConfig rangeOrderConfig)PriceOffsetAction(uint32 baseToken,int160 priceLowerOffset,int160 priceUpperOffset)PriceOffsetCondition(uint32 baseToken,uint256 gtePriceOffset,uint256 ltePriceOffset)RangeOrderAction(int256 maxGasProportion,int256 swapSlippage,int256 withdrawSlippage)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RebalanceAction(int256 maxGasProportion,int256 swapSlippage,int256 liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,int256 token0Ratio)TokenRatioCondition(int256 lteToken0Ratio,int256 gteToken0Ratio)"
    // );
    bytes32 constant Order_TYPEHASH = 0x01f2876587f15d6bfcddd0c4bf8e5d4d6eb2da2ab6809b0ca31abedd700c5f6c;
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