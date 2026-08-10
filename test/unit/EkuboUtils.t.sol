// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EkuboUtils, IWETH9} from "../../src/EkuboUtils.sol";
import {EkuboPoolKey, IEkuboPositions} from "../../src/interfaces/IEkuboPositions.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockWETH is MockERC20 {
    constructor() MockERC20("Wrapped Ether", "WETH") {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool sent,) = msg.sender.call{value: amount}("");
        require(sent, "ETH_SEND");
    }

    receive() external payable {}
}

contract MockEkuboCore {
    using SafeERC20 for IERC20;

    function pay(address token, address to, uint256 amount) external {
        if (token == address(0)) {
            (bool sent,) = to.call{value: amount}("");
            require(sent, "ETH_SEND");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    receive() external payable {}
}

contract MockEkuboPositions is ERC721 {
    using SafeERC20 for IERC20;

    struct StoredPosition {
        uint128 liquidity;
        uint128 principal0;
        uint128 principal1;
        uint128 fees0;
        uint128 fees1;
    }

    MockEkuboCore public immutable core;
    uint256 public nextId = 1;
    bool public useHalf;
    mapping(bytes32 => StoredPosition) internal _position;

    constructor(MockEkuboCore _core) ERC721("Ekubo Positions", "EKP") {
        core = _core;
    }

    modifier authorized(uint256 id) {
        require(_isApprovedOrOwner(msg.sender, id), "NOT_AUTHORIZED");
        _;
    }

    function setUseHalf(bool value) external {
        useHalf = value;
    }

    function setFees(uint256 id, EkuboPoolKey memory key, int32 lower, int32 upper, uint128 fee0, uint128 fee1)
        external
    {
        StoredPosition storage stored = _position[_key(id, key, lower, upper)];
        stored.fees0 = fee0;
        stored.fees1 = fee1;
    }

    function getPositionFeesAndLiquidity(uint256 id, EkuboPoolKey memory key, int32 lower, int32 upper)
        external
        view
        returns (uint128 liquidity, uint128 principal0, uint128 principal1, uint128 fees0, uint128 fees1)
    {
        StoredPosition storage stored = _position[_key(id, key, lower, upper)];
        return (stored.liquidity, stored.principal0, stored.principal1, stored.fees0, stored.fees1);
    }

    function deposit(
        uint256 id,
        EkuboPoolKey memory key,
        int32 lower,
        int32 upper,
        uint128 maxAmount0,
        uint128 maxAmount1,
        uint128 minLiquidity
    ) public payable authorized(id) returns (uint128 liquidity, uint128 amount0, uint128 amount1) {
        amount0 = useHalf ? maxAmount0 / 2 : maxAmount0;
        amount1 = useHalf ? maxAmount1 / 2 : maxAmount1;
        liquidity = amount0 + amount1;
        require(liquidity >= minLiquidity, "SLIPPAGE");

        _take(key.token0, msg.sender, amount0);
        _take(key.token1, msg.sender, amount1);

        StoredPosition storage stored = _position[_key(id, key, lower, upper)];
        stored.liquidity += liquidity;
        stored.principal0 += amount0;
        stored.principal1 += amount1;
    }

    function withdraw(
        uint256 id,
        EkuboPoolKey memory key,
        int32 lower,
        int32 upper,
        uint128 liquidity,
        address recipient,
        bool withFees
    ) external payable authorized(id) returns (uint128 amount0, uint128 amount1) {
        StoredPosition storage stored = _position[_key(id, key, lower, upper)];
        require(liquidity <= stored.liquidity, "LIQUIDITY");

        if (liquidity != 0) {
            amount0 = uint128(uint256(stored.principal0) * liquidity / stored.liquidity);
            amount1 = uint128(uint256(stored.principal1) * liquidity / stored.liquidity);
            stored.principal0 -= amount0;
            stored.principal1 -= amount1;
            stored.liquidity -= liquidity;
        }
        if (withFees) {
            amount0 += stored.fees0;
            amount1 += stored.fees1;
            stored.fees0 = 0;
            stored.fees1 = 0;
        }

        core.pay(key.token0, recipient, amount0);
        core.pay(key.token1, recipient, amount1);
    }

    function mintAndDeposit(
        EkuboPoolKey memory key,
        int32 lower,
        int32 upper,
        uint128 maxAmount0,
        uint128 maxAmount1,
        uint128 minLiquidity
    ) external payable returns (uint256 id, uint128 liquidity, uint128 amount0, uint128 amount1) {
        id = nextId++;
        _mint(msg.sender, id);
        (liquidity, amount0, amount1) = deposit(id, key, lower, upper, maxAmount0, maxAmount1, minLiquidity);
    }

    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i; i < data.length; ++i) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(result, 32), mload(result))
                }
            }
            results[i] = result;
        }
    }

    function refundNativeToken() external payable {
        uint256 balance = address(this).balance;
        if (balance != 0) {
            (bool sent,) = msg.sender.call{value: balance}("");
            require(sent, "ETH_REFUND");
        }
    }

    function _take(address token, address from, uint256 amount) internal {
        if (amount == 0) return;
        if (token == address(0)) {
            require(address(this).balance >= amount, "NATIVE_AMOUNT");
            (bool sent,) = address(core).call{value: amount}("");
            require(sent, "ETH_SEND");
        } else {
            IERC20(token).safeTransferFrom(from, address(core), amount);
        }
    }

    function _key(uint256 id, EkuboPoolKey memory key, int32 lower, int32 upper) internal pure returns (bytes32) {
        return keccak256(abi.encode(id, key, lower, upper));
    }
}

contract MockAllowanceHolder {
    using SafeERC20 for IERC20;

    function swap(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, uint256 amountOut) external {
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        tokenOut.safeTransfer(msg.sender, amountOut);
    }
}

contract EkuboUtilsTest is Test {
    address internal user = makeAddr("user");

    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    MockWETH internal weth;
    MockEkuboCore internal core;
    MockEkuboPositions internal positions;
    MockAllowanceHolder internal allowanceHolder;
    EkuboUtils internal utils;
    IERC20 internal token0;
    IERC20 internal token1;
    EkuboUtils.PositionSpec internal position;

    function setUp() external {
        tokenA = new MockERC20("Token A", "A");
        tokenB = new MockERC20("Token B", "B");
        weth = new MockWETH();
        core = new MockEkuboCore();
        positions = new MockEkuboPositions(core);
        allowanceHolder = new MockAllowanceHolder();
        utils = new EkuboUtils(
            IEkuboPositions(address(positions)), address(core), IWETH9(address(weth)), address(allowanceHolder)
        );

        (token0, token1) = address(tokenA) < address(tokenB)
            ? (IERC20(address(tokenA)), IERC20(address(tokenB)))
            : (IERC20(address(tokenB)), IERC20(address(tokenA)));
        position = EkuboUtils.PositionSpec({
            poolKey: EkuboPoolKey(address(token0), address(token1), _concentratedConfig(10)),
            tickLower: -20,
            tickUpper: 20
        });

        tokenA.mint(user, 1_000_000 ether);
        tokenB.mint(user, 1_000_000 ether);
        tokenA.mint(address(allowanceHolder), 1_000_000 ether);
        tokenB.mint(address(allowanceHolder), 1_000_000 ether);
        vm.deal(user, 10 ether);

        vm.startPrank(user);
        tokenA.approve(address(utils), type(uint256).max);
        tokenB.approve(address(utils), type(uint256).max);
        weth.approve(address(utils), type(uint256).max);
        vm.stopPrank();
    }

    function testSwapAndMintCreatesPositionAndReturnsNft() external {
        uint256 tokenId = _mintPosition(100, 200);

        assertEq(positions.ownerOf(tokenId), user);
        (uint128 liquidity, uint128 principal0, uint128 principal1,,) =
            positions.getPositionFeesAndLiquidity(tokenId, position.poolKey, position.tickLower, position.tickUpper);
        assertEq(liquidity, 300);
        assertEq(principal0, 100);
        assertEq(principal1, 200);
        assertEq(token0.balanceOf(address(utils)), 0);
        assertEq(token1.balanceOf(address(utils)), 0);
    }

    function testSwapReturnsOutputAndUnusedInput() external {
        uint256 outputBefore = token1.balanceOf(user);
        EkuboUtils.SwapParams memory params = EkuboUtils.SwapParams({
            tokenIn: token0,
            tokenOut: token1,
            amountIn: 100,
            minAmountOut: 75,
            deadline: block.timestamp,
            recipient: user,
            swapData: _swapData(token0, token1, 80, 75),
            unwrap: false
        });

        vm.prank(user);
        uint256 amountOut = utils.swap(params);

        assertEq(amountOut, 75);
        assertEq(token1.balanceOf(user) - outputBefore, 75);
        assertEq(token0.balanceOf(address(utils)), 0);
        assertEq(token1.balanceOf(address(utils)), 0);
        assertEq(token0.allowance(address(utils), address(allowanceHolder)), 0);
    }

    function testSwapRejectsExpiredDeadline() external {
        vm.warp(2);
        EkuboUtils.SwapParams memory params = EkuboUtils.SwapParams({
            tokenIn: token0,
            tokenOut: token1,
            amountIn: 100,
            minAmountOut: 75,
            deadline: 1,
            recipient: user,
            swapData: _swapData(token0, token1, 80, 75),
            unwrap: false
        });

        vm.prank(user);
        vm.expectRevert(EkuboUtils.DeadlineExpired.selector);
        utils.swap(params);
    }

    function testSwapAndMintRebalancesOnePoolToken() external {
        EkuboUtils.SwapAndMintParams memory params = _mintParams(position, 300, 0);
        params.swapSourceToken = token0;
        params.amountIn1 = 100;
        params.amountOut1Min = 80;
        params.swapData1 = _swapData(token0, token1, 100, 80);
        params.minLiquidity = 280;

        vm.prank(user);
        (uint256 tokenId, uint128 liquidity, uint128 amount0, uint128 amount1) = utils.swapAndMint(params);

        assertEq(liquidity, 280);
        assertEq(amount0, 200);
        assertEq(amount1, 80);
        assertEq(positions.ownerOf(tokenId), user);
        assertEq(token0.balanceOf(address(utils)), 0);
        assertEq(token1.balanceOf(address(utils)), 0);
    }

    function testAddLiquidityUsesTemporaryNftCustodyWithoutApproval() external {
        uint256 tokenId = _mintPosition(100, 200);
        assertEq(positions.getApproved(tokenId), address(0));

        EkuboUtils.Instructions memory instructions = _instructions(EkuboUtils.WhatToDo.ADD_LIQUIDITY);
        instructions.amount0 = 50;
        instructions.amount1 = 70;
        instructions.minLiquidity = 120;

        vm.prank(user);
        positions.safeTransferFrom(user, address(utils), tokenId, abi.encode(instructions));

        (uint128 totalLiquidity,,,,) =
            positions.getPositionFeesAndLiquidity(tokenId, position.poolKey, position.tickLower, position.tickUpper);
        assertEq(totalLiquidity, 420);
        assertEq(positions.ownerOf(tokenId), user);
        assertEq(positions.getApproved(tokenId), address(0));
    }

    function testAddLiquidityCanSwapWhileNftIsInTemporaryCustody() external {
        uint256 tokenId = _mintPosition(100, 200);
        EkuboUtils.Instructions memory instructions = _instructions(EkuboUtils.WhatToDo.ADD_LIQUIDITY);
        instructions.amount0 = 300;
        instructions.swapSourceToken = address(token0);
        instructions.amountIn1 = 100;
        instructions.amountOut1Min = 80;
        instructions.swapData1 = _swapData(token0, token1, 100, 80);
        instructions.minLiquidity = 280;

        vm.prank(user);
        positions.safeTransferFrom(user, address(utils), tokenId, abi.encode(instructions));

        (uint128 liquidity, uint128 principal0, uint128 principal1,,) =
            positions.getPositionFeesAndLiquidity(tokenId, position.poolKey, position.tickLower, position.tickUpper);
        assertEq(liquidity, 580);
        assertEq(principal0, 300);
        assertEq(principal1, 280);
        assertEq(positions.ownerOf(tokenId), user);
        assertEq(positions.getApproved(tokenId), address(0));
    }

    function testApprovedNftOperatorCannotPullOwnersDepositTokens() external {
        uint256 tokenId = _mintPosition(100, 200);
        address operator = makeAddr("operator");
        EkuboUtils.Instructions memory instructions = _instructions(EkuboUtils.WhatToDo.ADD_LIQUIDITY);
        instructions.amount0 = 50;
        instructions.amount1 = 70;
        instructions.minLiquidity = 120;
        uint256 balance0Before = token0.balanceOf(user);
        uint256 balance1Before = token1.balanceOf(user);

        vm.prank(user);
        positions.setApprovalForAll(operator, true);
        vm.prank(operator);
        vm.expectRevert(EkuboUtils.NftOwnerOnly.selector);
        positions.safeTransferFrom(user, address(utils), tokenId, abi.encode(instructions));

        assertEq(positions.ownerOf(tokenId), user);
        assertEq(token0.balanceOf(user), balance0Before);
        assertEq(token1.balanceOf(user), balance1Before);
    }

    function testExecuteConvenienceClearsOneTokenNftApproval() external {
        uint256 tokenId = _mintPosition(100, 200);
        EkuboUtils.Instructions memory instructions = _instructions(EkuboUtils.WhatToDo.ADD_LIQUIDITY);
        instructions.amount0 = 50;
        instructions.amount1 = 70;
        instructions.minLiquidity = 120;

        vm.prank(user);
        positions.approve(address(utils), tokenId);
        assertEq(positions.getApproved(tokenId), address(utils));
        vm.prank(user);
        utils.execute(tokenId, instructions);

        (uint128 liquidity,,,,) =
            positions.getPositionFeesAndLiquidity(tokenId, position.poolKey, position.tickLower, position.tickUpper);
        assertEq(liquidity, 420);
        assertEq(positions.ownerOf(tokenId), user);
        assertEq(positions.getApproved(tokenId), address(0));
    }

    function testCompoundCollectsFeesAndAddsThemToSameRange() external {
        uint256 tokenId = _mintPosition(100, 200);
        positions.setFees(tokenId, position.poolKey, position.tickLower, position.tickUpper, 10, 20);
        MockERC20(address(token0)).mint(address(core), 10);
        MockERC20(address(token1)).mint(address(core), 20);

        EkuboUtils.Instructions memory instructions = _instructions(EkuboUtils.WhatToDo.COMPOUND_FEES);
        instructions.collectFees = true;
        instructions.minLiquidity = 30;
        _execute(tokenId, instructions);

        (uint128 liquidity, uint128 principal0, uint128 principal1, uint128 fees0, uint128 fees1) =
            positions.getPositionFeesAndLiquidity(tokenId, position.poolKey, position.tickLower, position.tickUpper);
        assertEq(liquidity, 330);
        assertEq(principal0, 110);
        assertEq(principal1, 220);
        assertEq(fees0, 0);
        assertEq(fees1, 0);
        assertEq(positions.ownerOf(tokenId), user);
    }

    function testMoveRangeFullyEmptiesOldRangeAndMintsNewNft() external {
        uint256 tokenId = _mintPosition(100, 200);
        EkuboUtils.Instructions memory instructions = _instructions(EkuboUtils.WhatToDo.CHANGE_RANGE);
        instructions.liquidity = 300;
        instructions.collectFees = true;
        instructions.minLiquidity = 300;
        instructions.newPosition = EkuboUtils.PositionSpec({poolKey: position.poolKey, tickLower: -40, tickUpper: 40});
        _execute(tokenId, instructions);

        (uint128 oldLiquidity,,,,) =
            positions.getPositionFeesAndLiquidity(tokenId, position.poolKey, position.tickLower, position.tickUpper);
        (uint128 newLiquidity, uint128 principal0, uint128 principal1,,) = positions.getPositionFeesAndLiquidity(
            2, instructions.newPosition.poolKey, instructions.newPosition.tickLower, instructions.newPosition.tickUpper
        );
        assertEq(oldLiquidity, 0);
        assertEq(newLiquidity, 300);
        assertEq(principal0, 100);
        assertEq(principal1, 200);
        assertEq(positions.ownerOf(tokenId), user);
        assertEq(positions.ownerOf(2), user);
        assertEq(positions.balanceOf(user), 2);
    }

    function testMoveRangeRejectsPartialWithdrawal() external {
        uint256 tokenId = _mintPosition(100, 200);
        EkuboUtils.Instructions memory instructions = _instructions(EkuboUtils.WhatToDo.CHANGE_RANGE);
        instructions.liquidity = 299;
        instructions.newPosition = EkuboUtils.PositionSpec({poolKey: position.poolKey, tickLower: -40, tickUpper: 40});

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(EkuboUtils.FullWithdrawalRequired.selector, 300, 299));
        positions.safeTransferFrom(user, address(utils), tokenId, abi.encode(instructions));
        assertEq(positions.ownerOf(tokenId), user);
    }

    function testWithdrawAndSwapReturnsSingleAsset() external {
        uint256 tokenId = _mintPosition(100, 200);
        uint256 balanceBefore = token0.balanceOf(user);

        EkuboUtils.Instructions memory instructions = _instructions(EkuboUtils.WhatToDo.WITHDRAW_AND_COLLECT_AND_SWAP);
        instructions.targetToken = address(token0);
        instructions.liquidity = 300;
        instructions.amountOut1Min = 150;
        instructions.swapData1 = _swapData(token1, token0, 200, 150);
        _execute(tokenId, instructions);

        assertEq(token0.balanceOf(user) - balanceBefore, 250);
        (uint128 liquidity,,,,) =
            positions.getPositionFeesAndLiquidity(tokenId, position.poolKey, position.tickLower, position.tickUpper);
        assertEq(liquidity, 0);
        assertEq(positions.ownerOf(tokenId), user);
    }

    function testNativeDepositRefundsUnusedEthAndCanUnwrapLeftover() external {
        positions.setUseHalf(true);
        vm.deal(address(utils), 7);
        EkuboUtils.PositionSpec memory nativePosition = EkuboUtils.PositionSpec({
            poolKey: EkuboPoolKey(address(0), address(token1), _concentratedConfig(10)), tickLower: -20, tickUpper: 20
        });
        uint256 ethBefore = user.balance;
        uint256 tokenBefore = token1.balanceOf(user);
        EkuboUtils.SwapAndMintParams memory params = _mintParams(nativePosition, 2 ether, 100);
        params.minLiquidity = uint128(1 ether + 50);
        params.unwrap = true;

        vm.prank(user);
        (uint256 tokenId,, uint128 amount0, uint128 amount1) = utils.swapAndMint{value: 2 ether}(params);

        assertEq(amount0, 1 ether);
        assertEq(amount1, 50);
        assertEq(user.balance, ethBefore - 1 ether);
        assertEq(token1.balanceOf(user), tokenBefore - 50);
        assertEq(address(utils).balance, 7);
        assertEq(weth.balanceOf(address(utils)), 0);
        assertEq(positions.ownerOf(tokenId), user);
    }

    function testRejectsExtensions() external {
        EkuboUtils.PositionSpec memory extensionPosition = position;
        extensionPosition.poolKey.config =
            bytes32((uint256(uint160(address(0x1234))) << 96) | uint256(uint32(0x8000000a)));
        EkuboUtils.SwapAndMintParams memory params = _mintParams(extensionPosition, 100, 200);

        vm.prank(user);
        vm.expectRevert(EkuboUtils.ExtensionsNotSupported.selector);
        utils.swapAndMint(params);
    }

    function testRejectsStableswapPools() external {
        EkuboUtils.PositionSpec memory stablePosition = position;
        stablePosition.poolKey.config = bytes32(uint256(10));
        EkuboUtils.SwapAndMintParams memory params = _mintParams(stablePosition, 100, 200);

        vm.prank(user);
        vm.expectRevert(EkuboUtils.StableswapNotSupported.selector);
        utils.swapAndMint(params);
    }

    function _mintPosition(uint256 amount0, uint256 amount1) internal returns (uint256 tokenId) {
        EkuboUtils.SwapAndMintParams memory params = _mintParams(position, amount0, amount1);
        vm.prank(user);
        (tokenId,,,) = utils.swapAndMint(params);
    }

    function _mintParams(EkuboUtils.PositionSpec memory spec, uint256 amount0, uint256 amount1)
        internal
        view
        returns (EkuboUtils.SwapAndMintParams memory params)
    {
        params = EkuboUtils.SwapAndMintParams({
            position: spec,
            amount0: amount0,
            amount1: amount1,
            recipient: user,
            recipientNFT: user,
            deadline: block.timestamp,
            swapSourceToken: IERC20(address(0)),
            amountIn0: 0,
            amountOut0Min: 0,
            swapData0: "",
            amountIn1: 0,
            amountOut1Min: 0,
            swapData1: "",
            // Test inputs are deliberately bounded to small values.
            // forge-lint: disable-next-line(unsafe-typecast)
            minLiquidity: uint128(amount0 + amount1),
            returnData: "",
            unwrap: false
        });
    }

    function _instructions(EkuboUtils.WhatToDo whatToDo)
        internal
        view
        returns (EkuboUtils.Instructions memory instructions)
    {
        instructions.whatToDo = whatToDo;
        instructions.position = position;
        instructions.deadline = block.timestamp;
        instructions.recipient = user;
        instructions.recipientNFT = user;
    }

    function _execute(uint256 tokenId, EkuboUtils.Instructions memory instructions) internal {
        vm.prank(user);
        positions.safeTransferFrom(user, address(utils), tokenId, abi.encode(instructions));
    }

    function _swapData(IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountIn, uint256 amountOut)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(MockAllowanceHolder.swap, (tokenIn_, tokenOut_, amountIn, amountOut));
    }

    function _concentratedConfig(uint32 tickSpacing) internal pure returns (bytes32) {
        return bytes32(uint256(uint32(0x80000000 | tickSpacing)));
    }
}
