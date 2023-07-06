// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/V3Utils.sol";

contract RP3Test is Test {
    uint256 mainnetFork;

    V3Utils v3utils;

    address chef = makeAddr("chef");
    address feeRecipient = makeAddr("sushi");

    INonfungiblePositionManager constant NPM = INonfungiblePositionManager(0x2214A42d8e2A1d20635c2cb0664422c528B6A432);

    address RP3 = 0x827179dD56d07A7eeA32e3873493835da2866976;

    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    function setUp() external {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        v3utils = new V3Utils(NPM, RP3);
        assertEq(address(v3utils), 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f);

        deal(chef, 1 ether);
        assertEq(chef.balance, 1 ether);
        deal(address(USDC), chef, 100e6);
        assertEq(USDC.balanceOf(chef), 100e6);
    }

    function testSwapUSDCDAIWithRP3() public {
        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            USDC,
            DAI,
            1000000, // 1 USDC
            0,
            chef,
            _get1USDCToDAIRP3SwapData(),
            false
        );

        vm.startPrank(chef);
        USDC.approve(address(v3utils), 1000000);
        uint256 amountOut = v3utils.swap(params);
        vm.stopPrank();

        uint256 inputTokenBalance = USDC.balanceOf(address(v3utils));

        // swapped to DAI - fee
        assertLt(amountOut, 1 ether);

        // input token no leftovers allowed
        assertEq(inputTokenBalance, 0);

        // no fees with router
        uint256 feeBalance = DAI.balanceOf(feeRecipient);
        assertEq(feeBalance, 0);
        uint256 otherFeeBalance = USDC.balanceOf(feeRecipient);
        assertEq(otherFeeBalance, 0);
    }

    function testSwapETHUSDCWithRP3() public {
        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            WETH,
            USDC,
            500000000000000000, // 0.5ETH
            1,
            chef,
            _get05ETHToUSDCRP3SwapData(),
            false
        );

        vm.startPrank(chef);
        uint256 amountOut = v3utils.swap{value: (1 ether) / 2}(params);
        vm.stopPrank();

        uint256 inputTokenBalance = address(v3utils).balance;

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

    function testSwapUSDCETHWithRP3() public {
        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            USDC,
            WETH,
            1000000, // 1USDC
            1,
            chef,
            _get1USDCToETHRP3SwapData(),
            true
        );

        vm.startPrank(chef);
        USDC.approve(address(v3utils), 1000000);
        uint256 amountOut = v3utils.swap(params);
        vm.stopPrank();

        uint256 inputTokenBalance = USDC.balanceOf(address(v3utils));

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

    function _get1USDCToDAIRP3SwapData() internal view returns (bytes memory) {
        // cast calldata "processRoute(address,uint256,address,uint256,address,bytes)" 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 1000000 0x6B175474E89094C44Da98b954EedeAC495271d0F 1 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f 0x02A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4801ffff00AaF5110db6e744ff70fB339DE037B990A20bdace005615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        return
            abi.encode(
                RP3,
                hex"2646478b000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000f42400000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000000000000000000000000000000000000010000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000004202a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4801ffff00aaf5110db6e744ff70fb339de037b990a20bdace005615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000000000000000000000000000000000000000000000000000000000"
            );
    }

    function _get05ETHToUSDCRP3SwapData() internal view returns (bytes memory) {
        // cast calldata "processRoute(address,uint256,address,uint256,address,bytes)" 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 500000000000000000 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 1 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f 0x02C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc201ffff00397FF1542f962076d0BFE58eA045FfA2d347ACa0005615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        return
            abi.encode(
                RP3,
                hex"2646478b000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000006f05b59d3b20000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000010000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000004202c02aaa39b223fe8d0a0e5c4f27ead9083c756cc201ffff00397ff1542f962076d0bfe58ea045ffa2d347aca0005615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000000000000000000000000000000000000000000000000000000000"
            );
    }

    function _get1USDCToETHRP3SwapData() internal view returns (bytes memory) {
        // cast calldata "processRoute(address,uint256,address,uint256,address,bytes)" 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 1000000 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 1 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f 0x02A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4801ffff00397FF1542f962076d0BFE58eA045FfA2d347ACa0015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        return
            abi.encode(
                RP3,
                hex"2646478b000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000010000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000004202a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4801ffff00397ff1542f962076d0bfe58ea045ffa2d347aca0015615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000000000000000000000000000000000000000000000000000000000"
            );
    }
}