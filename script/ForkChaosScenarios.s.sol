pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EngineVault} from "../contracts/core/EngineVault.sol";
import {VolatilityOracle} from "../contracts/core/VolatilityOracle.sol";
import {IERC20} from "../contracts/interfaces/IERC20.sol";
import {PancakeLibrary} from "../contracts/libs/PancakeLibrary.sol";
import {MockERC20} from "../test/MockERC20.sol";
import {MockVaultOracle, MockLpPair, MockHedgeDiamond} from "../test/helpers/AssuranceMocks.sol";
import {MockPricePair, MockPancakeFactory, MockPancakePairLocking, MockPancakeRouter, MockVolOracleStorm} from "./helpers/ChaosMocks.sol";

contract ForkChaosScenarios is Script {
    address internal constant ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address internal constant FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address internal constant ACTOR = address(0xBEEF);

    function run() external {
        _selectForkIfConfigured();

        console2.log("Running fork-chaos scenarios...");
        _scenarioOracleDivergenceTriggersOnlyUnwind();
        _scenarioBlockedCloseTradeRevertsCycle();
        _scenarioCooldownBlocksUnwindBurn();
        _scenarioGasSpikeBountyStaysBounded();
        _scenarioFlashReserveCapStillRepays();
        console2.log("Fork-chaos scenarios PASS");
    }

    function _selectForkIfConfigured() internal {
        string memory rpcUrl = vm.envOr("BSC_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            console2.log("BSC_RPC_URL not set; running chaos scenarios in local script context.");
            return;
        }

        uint256 forkBlock = vm.envOr("BSC_FORK_BLOCK", uint256(0));
        if (forkBlock == 0) {
            vm.createSelectFork(rpcUrl);
        } else {
            vm.createSelectFork(rpcUrl, forkBlock);
        }

        console2.log("Fork selected. ChainId", block.chainid);
        console2.log("Fork block", block.number);
    }

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

    function _deployBountyVault(uint16 profitBountyBps, uint16 maxBountyBps, uint16 bufferCapBps, uint256 maxGasPrice)
        internal
        returns (EngineVault vault, MockERC20 asset, MockPricePair pair)
    {
        asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 bnb = new MockERC20("BNB", "BNB", 18);
        pair = new MockPricePair(address(asset), address(bnb));

        vault = new EngineVault(
            EngineVault.Addresses({
                asset: IERC20(address(asset)),
                asterDiamond: address(0),
                pancakeFactory: address(0),
                v2Pair: address(0),
                pairBase: address(0),
                pairQuote: address(0),
                bnbUsdtPair: address(pair),
                volatilityOracle: VolatilityOracle(address(0)),
                flashPair: address(0)
            }),
            EngineVault.Config({
                enableExternalCalls: false,
                minCycleInterval: 0,
                rebalanceThresholdBps: 500,
                deltaBandBps: 200,
                profitBountyBps: profitBountyBps,
                maxBountyBps: maxBountyBps,
                bufferCapBps: bufferCapBps,
                calmAlpBps: 4000,
                calmLpBps: 5700,
                normalAlpBps: 6000,
                normalLpBps: 3700,
                stormAlpBps: 8000,
                stormLpBps: 1700,
                safeCycleThreshold: 3,
                maxGasPrice: maxGasPrice,
                swapSlippageBps: 50
            })
        );
    }

    function _scenarioOracleDivergenceTriggersOnlyUnwind() internal {
        MockERC20 asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        MockERC20 alp = new MockERC20("ALP", "ALP", 18);
        MockLpPair pair = new MockLpPair(address(base), address(asset));
        MockVaultOracle oracle = new MockVaultOracle(address(pair), 1, 1e18);
        MockHedgeDiamond diamond = new MockHedgeDiamond(address(alp), address(asset), address(base));
        EngineVault vault = _deployVault(asset, base, diamond, address(pair), address(oracle), true, 200, 3700);

        pair.setReserves(1e18, 5e17);
        asset.mint(address(vault), 100e18);

        vault.cycle();
        require(uint256(vault.riskMode()) == uint256(EngineVault.RiskMode.ONLY_UNWIND), "CHAOS_ORACLE_MODE");

        asset.mint(ACTOR, 10e18);
        vm.startPrank(ACTOR);
        asset.approve(address(vault), 10e18);
        (bool ok,) = address(vault).call(abi.encodeWithSignature("deposit(uint256,address)", 10e18, ACTOR));
        vm.stopPrank();
        require(!ok, "CHAOS_ORACLE_DEPOSIT");
        console2.log("PASS: oracle divergence -> ONLY_UNWIND + deposit paused");
    }

    function _scenarioBlockedCloseTradeRevertsCycle() internal {
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

        bool reverted;
        try vault.cycle() {
            reverted = false;
        } catch Error(string memory reason) {
            reverted = true;
            require(keccak256(bytes(reason)) == keccak256(bytes("CLOSE_BLOCKED")), "CHAOS_CLOSE_REASON");
        } catch {
            reverted = true;
        }

        require(reverted, "CHAOS_CLOSE_REVERT");
        console2.log("PASS: blocked closeTrade -> safe revert");
    }

    function _scenarioCooldownBlocksUnwindBurn() internal {
        MockERC20 asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        MockERC20 alp = new MockERC20("ALP", "ALP", 18);
        MockHedgeDiamond diamond = new MockHedgeDiamond(address(alp), address(asset), address(base));
        EngineVault vault = _deployVault(asset, base, diamond, address(0), address(0), true, 200, 0);

        alp.mint(address(vault), 25e18);
        diamond.setCooldown(1 days);
        diamond.setLastMintedTimestamp(block.timestamp);

        vault.unwindForWithdraw(10e18);
        require(alp.balanceOf(address(vault)) == 25e18, "CHAOS_COOLDOWN_ALP");
        require(asset.balanceOf(address(vault)) == 0, "CHAOS_COOLDOWN_ASSET");
        console2.log("PASS: cooldown blocks unwind burn");
    }

    function _scenarioGasSpikeBountyStaysBounded() internal {
        (EngineVault vault, MockERC20 asset, MockPricePair pair) = _deployBountyVault(0, 10000, 10000, 5 gwei);
        pair.setReserves(300e18, 1e18);
        asset.mint(address(vault), 1000e18);

        vm.txGasPrice(100 gwei);
        uint256 gasPriceUsed = 5 gwei;
        uint256 bnbPrice = 300e18;
        uint256 minBounty = (gasPriceUsed * 500_000 * bnbPrice) / 1e18;
        minBounty = (minBounty * 150) / 100;

        address caller = address(0xCA11);
        vm.prank(caller);
        vault.cycle();

        require(asset.balanceOf(caller) == minBounty, "CHAOS_GAS_BOUNTY");
        console2.log("PASS: gas spike bounty remains capped");
    }

    function _scenarioFlashReserveCapStillRepays() internal {
        MockERC20 quote = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        MockERC20 wbnb = new MockERC20("WBNB", "WBNB", 18);

        MockPancakePairLocking v2Pair = new MockPancakePairLocking(address(base), address(quote));
        MockPancakePairLocking flashPair = new MockPancakePairLocking(address(base), address(wbnb));

        MockPancakeFactory factoryImpl = new MockPancakeFactory();
        vm.etch(FACTORY, address(factoryImpl).code);
        MockPancakeRouter routerImpl = new MockPancakeRouter();
        vm.etch(ROUTER, address(routerImpl).code);

        MockPancakeFactory(FACTORY).setPair(address(base), address(quote), address(v2Pair));
        MockPancakeFactory(FACTORY).setPair(address(base), address(wbnb), address(flashPair));

        uint256 lpReserveBase = 1_000_000e18;
        uint256 lpReserveQuote = 1_000_000e18;
        base.mint(address(v2Pair), lpReserveBase);
        quote.mint(address(v2Pair), lpReserveQuote);
        v2Pair.setReserves(uint112(lpReserveBase), uint112(lpReserveQuote));

        uint256 flashReserveBase = 1_000e18;
        uint256 flashReserveWbnb = 100e18;
        base.mint(address(flashPair), flashReserveBase);
        wbnb.mint(address(flashPair), flashReserveWbnb);
        flashPair.setReserves(uint112(flashReserveBase), uint112(flashReserveWbnb));

        MockVolOracleStorm oracle = new MockVolOracleStorm(address(v2Pair), 1e18);

        EngineVault vault = new EngineVault(
            EngineVault.Addresses({
                asset: IERC20(address(quote)),
                asterDiamond: address(0),
                pancakeFactory: address(0),
                v2Pair: address(v2Pair),
                pairBase: address(base),
                pairQuote: address(quote),
                bnbUsdtPair: address(0),
                volatilityOracle: VolatilityOracle(address(oracle)),
                flashPair: address(flashPair)
            }),
            EngineVault.Config({
                enableExternalCalls: true,
                minCycleInterval: 0,
                rebalanceThresholdBps: 50,
                deltaBandBps: 200,
                profitBountyBps: 0,
                maxBountyBps: 0,
                bufferCapBps: 10000,
                calmAlpBps: 0,
                calmLpBps: 0,
                normalAlpBps: 0,
                normalLpBps: 0,
                stormAlpBps: 0,
                stormLpBps: 0,
                safeCycleThreshold: 3,
                maxGasPrice: 0,
                swapSlippageBps: 50
            })
        );

        v2Pair.mintLp(address(vault), 1000e18);

        uint256 expectedBorrow = flashReserveBase / 10;
        uint256 expectedRepay = PancakeLibrary.getAmountIn(expectedBorrow, flashReserveWbnb, flashReserveBase);
        wbnb.mint(address(vault), expectedRepay);

        vault.cycle();

        require(v2Pair.balanceOf(address(vault)) == 0, "CHAOS_FLASH_LP");
        require(wbnb.balanceOf(address(vault)) == 0, "CHAOS_FLASH_REPAY");
        console2.log("PASS: flash reserve cap still repays under constrained liquidity");
    }
}
