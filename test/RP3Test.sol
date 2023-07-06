// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/V3Utils.sol";
import "./utils/BaseTest.sol";
import "./utils/IRouteProcessor.sol";
import "./utils/RouteProcessorHelper.sol";

contract RP3Test is BaseTest {
    V3Utils v3Utils;

    address user = makeAddr("user");
    address feeRecipient = makeAddr("sushiswap");

    INonfungiblePositionManager public nonfungiblePositionManager;
    IRouteProcessor public routeProcessor;
    RouteProcessorHelper routeProcessorHelper;

    IERC20 public WETH;
    IERC20 public USDC;
    IERC20 public SUSHI;

    function setUp() public override {
        forkMainnet();
        super.setUp();

        WETH = IERC20(constants.getAddress("mainnet.weth"));
        USDC = IERC20(constants.getAddress("mainnet.usdc"));
        SUSHI = IERC20(constants.getAddress("mainnet.sushi"));

        nonfungiblePositionManager = INonfungiblePositionManager(constants.getAddress("mainnet.nonfungiblePositionManager"));
        routeProcessor = IRouteProcessor(
            constants.getAddress("mainnet.routeProcessor")
        );
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
            300,
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
            300,
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
            300,
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
}