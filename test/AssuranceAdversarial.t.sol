pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EngineVault} from "../contracts/core/EngineVault.sol";
import {IERC20} from "../contracts/interfaces/IERC20.sol";
import {VolatilityOracle} from "../contracts/core/VolatilityOracle.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockVaultOracle, MockLpPair, MockHedgeDiamond} from "./helpers/AssuranceMocks.sol";

contract AssuranceAdversarialTest is Test {
    function _deployVault(
        MockERC20 asset,
        MockERC20 base,
        MockHedgeDiamond diamond,
        address pair,
        address oracle,
        bool enableExternalCalls,
        uint16 deltaBandBps,
        uint16 lpBps
    ) internal returns (EngineVault vault) {
        vault = new EngineVault(
            EngineVault.Addresses({
                asset: IERC20(address(asset)),
                asterDiamond: address(diamond),
                pancakeFactory: address(0),
                v2Pair: pair,
                pairBase: address(base),
                pairQuote: address(asset),
                bnbUsdtPair: address(0),
                volatilityOracle: VolatilityOracle(oracle),
                flashPair: address(0)
            }),
            EngineVault.Config({
                enableExternalCalls: enableExternalCalls,
                minCycleInterval: 0,
                rebalanceThresholdBps: 50,
                deltaBandBps: deltaBandBps,
                profitBountyBps: 0,
                maxBountyBps: 0,
                bufferCapBps: 10000,
                calmAlpBps: 0,
                calmLpBps: lpBps,
                normalAlpBps: 0,
                normalLpBps: lpBps,
                stormAlpBps: 0,
                stormLpBps: lpBps,
                safeCycleThreshold: 2,
                maxGasPrice: 0,
                swapSlippageBps: 50
            })
        );
    }

    function testOnlyUnwindSkipsRiskAddingLpRebalance() public {
        MockERC20 asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        MockERC20 alp = new MockERC20("ALP", "ALP", 18);
        MockLpPair pair = new MockLpPair(address(base), address(asset));
        MockVaultOracle oracle = new MockVaultOracle(address(pair), 1, 1e18);
        MockHedgeDiamond diamond = new MockHedgeDiamond(address(alp), address(asset), address(base));
        EngineVault vault = _deployVault(asset, base, diamond, address(pair), address(oracle), true, 200, 3700);

        pair.setReserves(1e18, 1e18);
        asset.mint(address(this), 100e18);
        asset.approve(address(vault), 100e18);
        vault.deposit(100e18, address(this));

        pair.setReserves(1e18, 5e17);
        vault.cycle();

        assertEq(uint256(vault.riskMode()), uint256(EngineVault.RiskMode.ONLY_UNWIND));
        assertEq(asset.balanceOf(address(vault)), 100e18);
        assertEq(pair.balanceOf(address(vault)), 0);
        assertEq(alp.balanceOf(address(vault)), 0);
    }

    function testCycleRevertsSafelyWhenOverhedgedCloseIsBlocked() public {
        MockERC20 asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        MockERC20 alp = new MockERC20("ALP", "ALP", 18);
        MockLpPair pair = new MockLpPair(address(base), address(asset));
        MockHedgeDiamond diamond = new MockHedgeDiamond(address(alp), address(asset), address(base));
        EngineVault vault = _deployVault(asset, base, diamond, address(pair), address(0), true, 0, 10000);

        pair.setReserves(1e18, 1e18);
        pair.setTotalSupply(1e18);
        pair.setBalance(address(vault), 6e17);
        diamond.setShortPosition(bytes32("short-a"), 60e18, uint80(8e9), uint64(100e8), 0, 0);
        diamond.setRevertOnCloseTrade(true);

        vm.expectRevert("CLOSE_BLOCKED");
        vault.cycle();
    }

    function testUnwindForWithdrawSkipsAlpBurnDuringCooldown() public {
        MockERC20 asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        MockERC20 alp = new MockERC20("ALP", "ALP", 18);
        MockHedgeDiamond diamond = new MockHedgeDiamond(address(alp), address(asset), address(base));
        EngineVault vault = _deployVault(asset, base, diamond, address(0), address(0), true, 200, 0);

        alp.mint(address(vault), 25e18);
        diamond.setCooldown(1 days);
        diamond.setLastMintedTimestamp(block.timestamp);

        vault.unwindForWithdraw(10e18);

        assertEq(alp.balanceOf(address(vault)), 25e18);
        assertEq(asset.balanceOf(address(vault)), 0);
    }
}
