// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/V3Utils.sol";
import "./utils/BaseTest.sol";
import "./utils/IRouteProcessor.sol";
import "./utils/RouteProcessorHelper.sol";
import "v3-periphery/interfaces/IQuoterV2.sol";

contract RP3Test is BaseTest {
    V3Utils v3Utils;

    address user = makeAddr("user");
    address feeRecipient = makeAddr("sushiswap");

    INonfungiblePositionManager public nonfungiblePositionManager;
    IRouteProcessor public routeProcessor;
    RouteProcessorHelper public routeProcessorHelper;
    IQuoterV2 public quoterV2;

    IERC20 public WETH;
    IERC20 public USDC;
    IERC20 public USDT;
    IERC20 public SUSHI;

    function setUp() public override {
        forkMainnet();
        super.setUp();

        WETH = IERC20(constants.getAddress("mainnet.weth"));
        USDC = IERC20(constants.getAddress("mainnet.usdc"));
        USDT = IERC20(constants.getAddress("mainnet.usdt"));
        SUSHI = IERC20(constants.getAddress("mainnet.sushi"));

        nonfungiblePositionManager = INonfungiblePositionManager(constants.getAddress("mainnet.nonfungiblePositionManager"));
        routeProcessor = IRouteProcessor(
            constants.getAddress("mainnet.routeProcessor")
        );
        quoterV2 = IQuoterV2(constants.getAddress("mainnet.quoterV2"));
        routeProcessorHelper = new RouteProcessorHelper(
            constants.getAddress("mainnet.v2Factory"),
            constants.getAddress("mainnet.v3Factory"),
            address(routeProcessor),
            address(WETH)
        );

        v3Utils = new V3Utils(nonfungiblePositionManager, address(routeProcessor));

        deal(user, 100 ether);
    }

    function testSwapWETH_SUSHI() public {
        uint256 amount = 1 ether / 2;

        deal(address(WETH), user, amount);
        assertEq(WETH.balanceOf(user), amount);

        bytes memory computedRoute = routeProcessorHelper.computeRoute(
            false,
            true, // isV2
            address(WETH),
            address(SUSHI),
            3000,
            address(v3Utils)
        );

        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            WETH,
            SUSHI,
            amount,
            1,
            user,
            abi.encode(
                address(routeProcessor),
                abi.encodeWithSelector(
                    routeProcessor.processRoute.selector,
                    address(WETH),
                    amount,
                    address(SUSHI),
                    1,
                    address(v3Utils),
                    computedRoute
                )
            ),
            false
        );

        vm.startPrank(user);
        WETH.approve(address(v3Utils), 1 ether);
        uint256 amountOut = v3Utils.swap(params);
        vm.stopPrank();

        uint256 inputTokenBalance = WETH.balanceOf(address(v3Utils));

        // assume SUSHI price < ETH price
        assertGt(amountOut, 0.5 ether);

        // input token no leftovers allowed
        assertEq(inputTokenBalance, 0);

        // no fees with router
        uint256 feeBalance = SUSHI.balanceOf(feeRecipient);
        assertEq(feeBalance, 0);
        uint256 otherFeeBalance = SUSHI.balanceOf(feeRecipient);
        assertEq(otherFeeBalance, 0);
    }

    function testSwapETH_USDC() public {
        uint256 amount = 1 ether / 2;

        deal(user, amount);
        assertEq(user.balance, amount);

        bytes memory computedRoute = routeProcessorHelper.computeRoute(
            false,
            true, // isV2
            address(WETH),
            address(USDC),
            3000,
            address(v3Utils)
        );

        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            WETH,
            USDC,
            amount, // 0.5ETH
            1,
            alice,
            abi.encode(
                address(routeProcessor),
                abi.encodeWithSelector(
                    routeProcessor.processRoute.selector,
                    address(WETH),
                    amount,
                    address(USDC),
                    1,
                    address(v3Utils),
                    computedRoute
                )
            ),
            false
        );

        vm.startPrank(alice);
        uint256 amountOut = v3Utils.swap{value: amount}(params);
        vm.stopPrank();

        uint256 inputTokenBalance = address(v3Utils).balance;

        // swapped to USDC - fee
        assertLt(amountOut, 1 ether);

        // input token no leftovers allowed
        assertEq(inputTokenBalance, 0);

        // no fees with router
        uint256 feeBalance = feeRecipient.balance;
        assertEq(feeBalance, 0);
        uint256 otherFeeBalance = USDC.balanceOf(feeRecipient);
        assertEq(otherFeeBalance, 0);
    }

    function testSwapUSDC_ETH() public {
        uint256 amount = 100000; // 1 USDC

        deal(address(USDC), user, amount);
        assertEq(USDC.balanceOf(user), amount);

        bytes memory computedRoute = routeProcessorHelper.computeRoute(
            false,
            true, // isV2
            address(USDC),
            address(WETH),
            3000,
            address(v3Utils)
        );

        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            USDC,
            WETH,
            amount,
            1,
            alice,
            abi.encode(
                address(routeProcessor),
                abi.encodeWithSelector(
                    routeProcessor.processRoute.selector,
                    address(USDC),
                    amount,
                    address(WETH),
                    1,
                    address(v3Utils),
                    computedRoute
                )
            ),
            true
        );

        vm.startPrank(alice);
        USDC.approve(address(v3Utils), amount);
        uint256 amountOut = v3Utils.swap(params);
        vm.stopPrank();

        uint256 inputTokenBalance = USDC.balanceOf(address(v3Utils));

        // swapped to ETH - fee
        assertLt(amountOut, 1 ether);

        // input token no leftovers allowed
        assertEq(inputTokenBalance, 0);

        // no fees with router
        uint256 feeBalance = feeRecipient.balance;
        assertEq(feeBalance, 0);
        uint256 otherFeeBalance = USDC.balanceOf(feeRecipient);
        assertEq(otherFeeBalance, 0);
    }

    function testZapInSUSHI_WETH() public {
        // zap in with SUSHI
        uint256 amount = 100 ether; // 100 sushi
        uint256 swapAmount = amount / 2;
        uint24 fee = 3000;

        deal(address(SUSHI), user, amount);

        // IUniswapV3Pool sushiWethPool = IUniswapV3Pool(0x87C7056BBE6084f03304196Be51c6B90B6d85Aa2);

        // TODO: just use RP to quote
        (, bytes memory quoteData) = address(quoterV2).call(
            abi.encodeWithSelector(
                quoterV2.quoteExactInputSingle.selector,
                IQuoterV2.QuoteExactInputSingleParams(address(SUSHI),
                address(WETH),
                swapAmount,
                fee,
                0)
            )
        );

        (uint256 quotedAmountOut, , ,) = abi.decode(quoteData, (uint256, uint160, uint32, uint256));

        bytes memory computedRoute = routeProcessorHelper.computeRoute(
            false,
            false, // isV2
            address(SUSHI),
            address(WETH),
            3000,
            address(v3Utils)
        );

        bytes memory swapData = abi.encode(
            address(routeProcessor),
            abi.encodeWithSelector(
                routeProcessor.processRoute.selector,
                address(SUSHI),
                swapAmount,
                address(WETH),
                1,
                address(v3Utils),
                computedRoute
            )
        );

        V3Utils.SwapAndMintParams memory params = V3Utils.SwapAndMintParams(
            SUSHI, //token0
            WETH, //token1
            fee, //fee
            -887220, //tickLower
            887220, //tickUpper
            amount, //amount0
            0, //amount1
            user, //dust recipient
            user, //nft recipient
            block.timestamp, //deadline
            SUSHI, //swapSourceToken
            0, //amountIn0
            0, //amountOut0Min
            "", //swapData0
            swapAmount, //amountIn1
            1, //amountOut1Min
            swapData, //swapData1
            1, //amountAddMin0
            1, //amountAddMin1
            "" //returnData
        );

        vm.startPrank(user);
        SUSHI.approve(address(v3Utils), amount);

        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = v3Utils.swapAndMint(params);

        vm.stopPrank();

        // TODO: check fee
        // uint256 feeBalance = DAI.balanceOf(TEST_FEE_ACCOUNT);
        // assertEq(feeBalance, 9845545793003026);

        assertGt(tokenId, 0);
        assertGt(liquidity, 0);
        assertGt(amount0, 0);
        assertGt(amount1, 0);

        assertEq(amount1, quotedAmountOut);
    }

    function testZapInWithETH() public {
        // zap in with ETH
        uint256 amount = 1 ether;
        uint256 swapAmount = amount / 2;
        uint24 fee = 100;

        deal(user, 2 ether);

        // IUniswapV3Pool usdcUsdtPool = IUniswapV3Pool(0xfA6e8E97ecECDC36302eCA534f63439b1E79487B);

        bytes memory route0 = routeProcessorHelper.computeRoute(
            false,
            false, // isV2
            address(WETH),
            address(USDC),
            500,
            address(v3Utils)
        );

        bytes memory swapData0 = abi.encode(
            address(routeProcessor),
            abi.encodeWithSelector(
                routeProcessor.processRoute.selector,
                address(WETH),
                swapAmount,
                address(USDC),
                1,
                address(v3Utils),
                route0
            )
        );

        bytes memory route1 = routeProcessorHelper.computeRoute(
            false,
            false, // isV2,
            address(WETH),
            address(USDT),
            500,
            address(v3Utils)
        );

        bytes memory swapData1 = abi.encode(
            address(routeProcessor),
            abi.encodeWithSelector(
                routeProcessor.processRoute.selector,
                address(WETH),
                swapAmount,
                address(USDT),
                1,
                address(v3Utils),
                route1
            )
        );

        V3Utils.SwapAndMintParams memory params = V3Utils.SwapAndMintParams(
            USDC, //token0
            USDT, //token1
            fee, //fee
            -887272, //tickLower
            887272, //tickUpper
            0, //amount0
            0, //amount1
            user, //dust recipient
            user, //nft recipient
            block.timestamp, //deadline
            WETH, //swapSourceToken
            swapAmount, //amountIn0
            1, //amountOut0Min
            swapData0, //swapData0
            swapAmount, //amountIn1
            1, //amountOut1Min
            swapData1, //swapData1
            0, //amountAddMin0
            0, //amountAddMin1
            "" //returnData
        );

        vm.startPrank(user);

        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = v3Utils.swapAndMint{value: 1 ether}(params);

        vm.stopPrank();

        // TODO: check fees
        // close to 1% of swapped amount
        // uint256 feeBalance = DAI.balanceOf(TEST_FEE_ACCOUNT);
        // assertEq(feeBalance, 9845545793003026);

        assertGt(tokenId, 0);
        assertGt(liquidity, 0);
        assertGt(amount0, 0);
        assertGt(amount1, 0);
    }
}