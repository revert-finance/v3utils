// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/console.sol";

contract Signature {
    bytes32 public DOMAIN_SEPARATOR;
    constructor(EIP712Domain memory eip712Domain) {
        DOMAIN_SEPARATOR = hash(eip712Domain);
        console.logBytes32(DOMAIN_SEPARATOR);
    }
    function recover(Order memory order, bytes memory signature) external view returns (address) {
        // Note: we need to use `encodePacked` here instead of `encode`.
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hash(order)
        ));
        return ECDSA.recover(digest, signature);
    }

    function hash(string memory s) internal pure returns (bytes32) {
        return hash(bytes(s));
    }

    function hash(bytes memory b) internal pure returns (bytes32) {
        return keccak256(b);
    }
    
    bytes32 constant EIP712Domain_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }
    function hash(EIP712Domain memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712Domain_TYPEHASH,
            hash(obj.name),
            hash(obj.version),
            obj.chainId,
            obj.verifyingContract
        ));
    }

    bytes32 constant AutoCompound_TYPEHASH = keccak256(
        "AutoCompound(AutoCompoundAction action)AutoCompoundAction(string maxGasProportion,string feeToPrincipalRatioThreshold)"
    );
    struct AutoCompound {
        AutoCompoundAction action;
    }
    function hash(AutoCompound memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            AutoCompound_TYPEHASH,
            hash(obj.action)
        ));
    }

    bytes32 constant AutoCompoundAction_TYPEHASH = keccak256(
        "AutoCompoundAction(string maxGasProportion,string feeToPrincipalRatioThreshold)"
    );
    struct AutoCompoundAction {
        string maxGasProportion;
        string feeToPrincipalRatioThreshold;
    }
    function hash(AutoCompoundAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            AutoCompoundAction_TYPEHASH,
            hash(obj.maxGasProportion),
            hash(obj.feeToPrincipalRatioThreshold)
        ));
    }

    bytes32 constant TickOffsetCondition_TYPEHASH = keccak256(
        "TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)"
    );
    struct TickOffsetCondition {
        uint32 gteTickOffset;
        uint32 lteTickOffset;
    }
    function hash(TickOffsetCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TickOffsetCondition_TYPEHASH,
            obj.gteTickOffset,
            obj.lteTickOffset
        ));
    }

    bytes32 constant PriceOffsetCondition_TYPEHASH = keccak256(
        "PriceOffsetCondition(uint32 baseToken,string gtePriceOffset,string ltePriceOffset)"
    );
    struct PriceOffsetCondition {
        uint32 baseToken;
        string gtePriceOffset;
        string ltePriceOffset;
    }
    function hash(PriceOffsetCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PriceOffsetCondition_TYPEHASH,
            obj.baseToken,
            hash(obj.gtePriceOffset),
            hash(obj.ltePriceOffset)
        ));
    }

    bytes32 constant TokenRatioCondition_TYPEHASH = keccak256(
        "TokenRatioCondition(string lteToken0Ratio,string gteToken0Ratio)"
    );
    struct TokenRatioCondition {
        string lteToken0Ratio;
        string gteToken0Ratio;
    }
    function hash(TokenRatioCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TokenRatioCondition_TYPEHASH,
            hash(obj.lteToken0Ratio),
            hash(obj.gteToken0Ratio)
        ));
    }

    bytes32 constant RebalanceCondition_TYPEHASH = keccak256(
        "RebalanceCondition(string type,string sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)PriceOffsetCondition(uint32 baseToken,string gtePriceOffset,string ltePriceOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioCondition(string lteToken0Ratio,string gteToken0Ratio)"
    );
    struct RebalanceCondition {
        string _type;
        string sqrtPriceX96;
        int64 timeBuffer;
        TickOffsetCondition tickOffsetCondition;
        PriceOffsetCondition priceOffsetCondition;
        TokenRatioCondition tokenRatioCondition;
    }
    function hash(RebalanceCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RebalanceCondition_TYPEHASH,
            hash(obj._type),
            hash(obj.sqrtPriceX96),
            obj.timeBuffer,
            hash(obj.tickOffsetCondition),
            hash(obj.priceOffsetCondition),
            hash(obj.tokenRatioCondition)
        ));
    }

    bytes32 constant TickOffsetAction_TYPEHASH = keccak256(
        "TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)"
    );
    struct TickOffsetAction {
        uint32 tickLowerOffset;
        uint32 tickUpperOffset;
    }
    function hash(TickOffsetAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TickOffsetAction_TYPEHASH,
            obj.tickLowerOffset,
            obj.tickUpperOffset
        ));
    }

    bytes32 constant PriceOffsetAction_TYPEHASH = keccak256(
        "PriceOffsetAction(uint32 baseToken,string priceLowerOffset,string priceUpperOffset)"
    );
    struct PriceOffsetAction {
        uint32 baseToken;
        string priceLowerOffset;
        string priceUpperOffset;
    }
    function hash(PriceOffsetAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PriceOffsetAction_TYPEHASH,
            obj.baseToken,
            hash(obj.priceLowerOffset),
            hash(obj.priceUpperOffset)
        ));
    }

    bytes32 constant TokenRatioAction_TYPEHASH = keccak256(
        "TokenRatioAction(uint32 tickWidth,string token0Ratio)"
    );
    struct TokenRatioAction {
        uint32 tickWidth;
        string token0Ratio;
    }
    function hash(TokenRatioAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TokenRatioAction_TYPEHASH,
            obj.tickWidth,
            hash(obj.token0Ratio)
        ));
    }

    bytes32 constant RebalanceAction_TYPEHASH = keccak256(
        "RebalanceAction(string maxGasProportion,string swapSlippage,string liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)PriceOffsetAction(uint32 baseToken,string priceLowerOffset,string priceUpperOffset)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TokenRatioAction(uint32 tickWidth,string token0Ratio)"
    );
    struct RebalanceAction {
        string maxGasProportion;
        string swapSlippage;
        string liquiditySlippage;
        string _type;
        TickOffsetAction tickOffsetAction;
        PriceOffsetAction priceOffsetAction;
        TokenRatioAction tokenRatioAction;
    }
    function hash(RebalanceAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RebalanceAction_TYPEHASH,
            hash(obj.maxGasProportion),
            hash(obj.swapSlippage),
            hash(obj.liquiditySlippage),
            hash(obj._type),
            hash(obj.tickOffsetAction),
            hash(obj.priceOffsetAction),
            hash(obj.tokenRatioAction)
        ));
    }

    bytes32 constant RebalanceConfig_TYPEHASH = keccak256(
        "RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)AutoCompound(AutoCompoundAction action)AutoCompoundAction(string maxGasProportion,string feeToPrincipalRatioThreshold)PriceOffsetAction(uint32 baseToken,string priceLowerOffset,string priceUpperOffset)PriceOffsetCondition(uint32 baseToken,string gtePriceOffset,string ltePriceOffset)RebalanceAction(string maxGasProportion,string swapSlippage,string liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,string sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,string token0Ratio)TokenRatioCondition(string lteToken0Ratio,string gteToken0Ratio)"
    );
    struct RebalanceConfig {
        RebalanceCondition rebalanceCondition;
        RebalanceAction rebalanceAction;
        AutoCompound autoCompound;
        bool recurring;
    }
    function hash(RebalanceConfig memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RebalanceConfig_TYPEHASH,
            hash(obj.rebalanceCondition),
            hash(obj.rebalanceAction),
            hash(obj.autoCompound),
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
    function hash(RangeOrderCondition memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RangeOrderCondition_TYPEHASH,
            obj.zeroToOne,
            obj.gteTickAbsolute,
            obj.lteTickAbsolute
        ));
    }

    bytes32 constant RangeOrderAction_TYPEHASH = keccak256(
        "RangeOrderAction(string maxGasProportion,string swapSlippage,string withdrawSlippage)"
    );
    struct RangeOrderAction {
        string maxGasProportion;
        string swapSlippage;
        string withdrawSlippage;
    }
    function hash(RangeOrderAction memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RangeOrderAction_TYPEHASH,
            hash(obj.maxGasProportion),
            hash(obj.swapSlippage),
            hash(obj.withdrawSlippage)
        ));
    }

    bytes32 constant RangeOrderConfig_TYPEHASH = keccak256(
        "RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RangeOrderAction(string maxGasProportion,string swapSlippage,string withdrawSlippage)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)"
    );
    struct RangeOrderConfig {
        RangeOrderCondition condition;
        RangeOrderAction action;
    }
    function hash(RangeOrderConfig memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RangeOrderConfig_TYPEHASH,
            hash(obj.condition),
            hash(obj.action)
        ));
    }

    bytes32 constant OrderConfig_TYPEHASH = keccak256(
        "OrderConfig(RebalanceConfig rebalanceConfig,RangeOrderConfig rangeOrderConfig)AutoCompound(AutoCompoundAction action)AutoCompoundAction(string maxGasProportion,string feeToPrincipalRatioThreshold)PriceOffsetAction(uint32 baseToken,string priceLowerOffset,string priceUpperOffset)PriceOffsetCondition(uint32 baseToken,string gtePriceOffset,string ltePriceOffset)RangeOrderAction(string maxGasProportion,string swapSlippage,string withdrawSlippage)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RebalanceAction(string maxGasProportion,string swapSlippage,string liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,string sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,string token0Ratio)TokenRatioCondition(string lteToken0Ratio,string gteToken0Ratio)"
    );
    struct OrderConfig {
        RebalanceConfig rebalanceConfig;
        RangeOrderConfig rangeOrderConfig;
    }
    function hash(OrderConfig memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OrderConfig_TYPEHASH,
            hash(obj.rebalanceConfig),
            hash(obj.rangeOrderConfig)
        ));
    }

    bytes32 constant Order_TYPEHASH = keccak256(
        "Order(int64 chainId,address nfpmAddress,string tokenId,string orderType,OrderConfig config)AutoCompound(AutoCompoundAction action)AutoCompoundAction(string maxGasProportion,string feeToPrincipalRatioThreshold)OrderConfig(RebalanceConfig rebalanceConfig,RangeOrderConfig rangeOrderConfig)PriceOffsetAction(uint32 baseToken,string priceLowerOffset,string priceUpperOffset)PriceOffsetCondition(uint32 baseToken,string gtePriceOffset,string ltePriceOffset)RangeOrderAction(string maxGasProportion,string swapSlippage,string withdrawSlippage)RangeOrderCondition(bool zeroToOne,int32 gteTickAbsolute,int32 lteTickAbsolute)RangeOrderConfig(RangeOrderCondition condition,RangeOrderAction action)RebalanceAction(string maxGasProportion,string swapSlippage,string liquiditySlippage,string type,TickOffsetAction tickOffsetAction,PriceOffsetAction priceOffsetAction,TokenRatioAction tokenRatioAction)RebalanceCondition(string type,string sqrtPriceX96,int64 timeBuffer,TickOffsetCondition tickOffsetCondition,PriceOffsetCondition priceOffsetCondition,TokenRatioCondition tokenRatioCondition)RebalanceConfig(RebalanceCondition rebalanceCondition,RebalanceAction rebalanceAction,AutoCompound autoCompound,bool recurring)TickOffsetAction(uint32 tickLowerOffset,uint32 tickUpperOffset)TickOffsetCondition(uint32 gteTickOffset,uint32 lteTickOffset)TokenRatioAction(uint32 tickWidth,string token0Ratio)TokenRatioCondition(string lteToken0Ratio,string gteToken0Ratio)"
    );
    struct Order {
        int64 chainId;
        address nfpmAddress;
        string tokenId;
        string orderType;
        OrderConfig config;
    }
    function hash(Order memory obj) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            Order_TYPEHASH,
            obj.chainId,
            obj.nfpmAddress,
            hash(obj.tokenId),
            hash(obj.orderType),
            hash(obj.config)
        ));
    }
}