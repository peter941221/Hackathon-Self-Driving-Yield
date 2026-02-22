pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FlashRebalancer} from "../contracts/adapters/FlashRebalancer.sol";

contract FlashRebalancerTest is Test {
    function testOnlyVault() public {
        FlashRebalancer rebalancer = new FlashRebalancer(address(0), address(0x1234), address(this));
        FlashRebalancer.RebalanceParams memory params =
            FlashRebalancer.RebalanceParams({borrowAmount: 1, borrowToken0: true});

        vm.prank(address(0xBEEF));
        vm.expectRevert();
        rebalancer.executeFlashRebalance(params);
    }
}
