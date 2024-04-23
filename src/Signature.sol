// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "forge-std/console.sol";

abstract contract Signature is EIP712 {

    constructor(string memory name, string memory version) EIP712(name, version){}
    
    function hashOrder(Order memory order) public pure returns (bytes32) {
        return _hash(order);
    }

    function _recover(Order memory order, bytes memory signature) internal view returns (address) {
        bytes32 digest = MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), _hash(order));
        return ECDSA.recover(digest, signature);
    }

    bytes32 constant AutoCompound_TYPEHASH = keccak256(
        "AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportion,int256 feeToPrincipalRatioThreshold)"
    );
    struct AutoCompound {
        AutoCompoundAction action;
    }
    function _hash(AutoCompound memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            AutoCompound_TYPEHASH,
            _hash(obj.action)
        ));
    }

    bytes32 constant AutoCompoundAction_TYPEHASH = keccak256(
        "AutoCompoundAction(int256 maxGasProportion,int256 feeToPrincipalRatioThreshold)"
    );
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

    bytes32 constant TickOffsetCondition_TYPEHASH = keccak256(
        "TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)"
    );
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

    bytes32 constant PriceOffsetCondition_TYPEHASH = keccak256(
        "PriceOffsetCondition(uint32 baseToken,uint256 gtePriceOffset,uint256 ltePriceOffset)"
    );
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

    bytes32 constant TokenRatioCondition_TYPEHASH = keccak256(
        "TokenRatioCondition(int256 lteToken0Ratio,int256 gteToken0Ratio)"
    );
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

    bytes32 constant RebalanceCondition_TYPEHASH = keccak256(
        "RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)PriceOffsetCondition(uint32 baseToken,uint256 gtePriceOffset,uint256 ltePriceOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioCondition(int256 lteToken0Ratio,int256 gteToken0Ratio)"
    );
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

    bytes32 constant TickOffsetAction_TYPEHASH = keccak256(
        "TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)"
    );
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

    bytes32 constant PriceOffsetAction_TYPEHASH = keccak256(
        "PriceOffsetAction(uint32 baseToken,int160 priceLowerOffset,int160 priceUpperOffset)"
    );
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

    bytes32 constant TokenRatioAction_TYPEHASH = keccak256(
        "TokenRatioAction(uint32 tickWidth,int256 token0Ratio)"
    );
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

    bytes32 constant RebalanceAction_TYPEHASH = keccak256(
        "RebalanceAction(int256 maxGasProportion,int256 swapSlippage,int256 liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)PriceOffsetAction(uint32 baseToken,int160 priceLowerOffset,int160 priceUpperOffset)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TokenRatioAction(uint32 tickWidth,int256 token0Ratio)"
    );
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

    bytes32 constant RebalanceConfig_TYPEHASH = keccak256(
        "RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportion,int256 feeToPrincipalRatioThreshold)PriceOffsetAction(uint32 baseToken,int160 priceLowerOffset,int160 priceUpperOffset)PriceOffsetCondition(uint32 baseToken,uint256 gtePriceOffset,uint256 ltePriceOffset)RebalanceAction(int256 maxGasProportion,int256 swapSlippage,int256 liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,int256 token0Ratio)TokenRatioCondition(int256 lteToken0Ratio,int256 gteToken0Ratio)"
    );
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

    bytes32 constant RangeOrderCondition_TYPEHASH = keccak256(
        "RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)"
    );
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

    bytes32 constant RangeOrderAction_TYPEHASH = keccak256(
        "RangeOrderAction(int256 maxGasProportion,int256 swapSlippage,int256 withdrawSlippage)"
    );
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

    bytes32 constant RangeOrderConfig_TYPEHASH = keccak256(
        "RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RangeOrderAction(int256 maxGasProportion,int256 swapSlippage,int256 withdrawSlippage)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)"
    );
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

    bytes32 constant OrderConfig_TYPEHASH = keccak256(
        "OrderConfig(RebalanceConfig rebalanceConfig,RangeOrderConfig rangeOrderConfig)AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportion,int256 feeToPrincipalRatioThreshold)PriceOffsetAction(uint32 baseToken,int160 priceLowerOffset,int160 priceUpperOffset)PriceOffsetCondition(uint32 baseToken,uint256 gtePriceOffset,uint256 ltePriceOffset)RangeOrderAction(int256 maxGasProportion,int256 swapSlippage,int256 withdrawSlippage)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RebalanceAction(int256 maxGasProportion,int256 swapSlippage,int256 liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,int256 token0Ratio)TokenRatioCondition(int256 lteToken0Ratio,int256 gteToken0Ratio)"
    );
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

    bytes32 constant Order_TYPEHASH = keccak256(
        "Order(int64 chainId,address nfpmAddress,uint256 tokenId,string orderType,OrderConfig config,int64 signatureTime)AutoCompound(AutoCompoundAction action)AutoCompoundAction(int256 maxGasProportion,int256 feeToPrincipalRatioThreshold)OrderConfig(RebalanceConfig rebalanceConfig,RangeOrderConfig rangeOrderConfig)PriceOffsetAction(uint32 baseToken,int160 priceLowerOffset,int160 priceUpperOffset)PriceOffsetCondition(uint32 baseToken,uint256 gtePriceOffset,uint256 ltePriceOffset)RangeOrderAction(int256 maxGasProportion,int256 swapSlippage,int256 withdrawSlippage)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RebalanceAction(int256 maxGasProportion,int256 swapSlippage,int256 liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,int160 sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,int256 token0Ratio)TokenRatioCondition(int256 lteToken0Ratio,int256 gteToken0Ratio)"
    );
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