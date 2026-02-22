pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Aster1001xAdapter} from "../contracts/adapters/Aster1001xAdapter.sol";

contract Aster1001xAdapterTest is Test {
    address internal constant DIAMOND = 0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0;

    function testUsdToQty() public {
        uint256 qty = Aster1001xAdapter.usdToQty(100e18, 25_000e8);
        assertGt(qty, 0);
    }

    function testGetPositionsReadable() public {
        string memory rpcUrl = vm.envOr("BSC_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            return;
        }
        uint256 forkBlock = vm.envOr("BSC_FORK_BLOCK", uint256(0));
        if (forkBlock == 0) {
            vm.createSelectFork(rpcUrl);
        } else {
            vm.createSelectFork(rpcUrl, forkBlock);
        }

        (bool ok, ) = DIAMOND.staticcall(abi.encodeWithSignature("getPositionsV2(address)", address(this)));
        if (!ok) {
            return;
        }
        (bytes32[] memory tradeHashes, uint256 totalQty) = Aster1001xAdapter.getPositions(DIAMOND, address(this));
        assertEq(tradeHashes.length, 0);
        assertEq(totalQty, 0);
    }
}
