pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EngineVault} from "../contracts/core/EngineVault.sol";
import {IERC20} from "../contracts/interfaces/IERC20.sol";
import {ITradingReader} from "../contracts/interfaces/ITradingReader.sol";
import {IAsterDiamond} from "../contracts/interfaces/IAsterDiamond.sol";
import {VolatilityOracle} from "../contracts/core/VolatilityOracle.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockVaultOracle {
    address public pair;
    uint8 public minSamples;
    uint8 public snapshotCount;
    uint256 public volatilityBps;
    uint256 public twapPrice1e18;

    constructor(address pair_, uint8 minSamples_, uint256 twapPrice1e18_) {
        pair = pair_;
        minSamples = minSamples_;
        twapPrice1e18 = twapPrice1e18_;
    }

    function recordSnapshot() external {
        snapshotCount++;
    }

    function setSnapshotCount(uint8 count) external {
        snapshotCount = count;
    }

    function setVolatilityBps(uint256 vol) external {
        volatilityBps = vol;
    }

    function setTwapPrice(uint256 price) external {
        twapPrice1e18 = price;
    }

    function getVolatilityBps() external view returns (uint256) {
        return volatilityBps;
    }

    function getRegime() external pure returns (VolatilityOracle.Regime) {
        return VolatilityOracle.Regime.NORMAL;
    }

    function getTwapPrice1e18() external view returns (uint256) {
        return twapPrice1e18;
    }
}

contract MockLpPair {
    address public token0;
    address public token1;
    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimestampLast;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setReserves(uint112 reserve0_, uint112 reserve1_) external {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
        blockTimestampLast = uint32(block.timestamp);
    }

    function setTotalSupply(uint256 totalSupply_) external {
        totalSupply = totalSupply_;
    }

    function setBalance(address account, uint256 amount) external {
        balanceOf[account] = amount;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }
}

contract MockHedgeDiamond {
    address public immutable alpToken;
    address public immutable marginToken;
    address public immutable pairBaseToken;
    uint256 public alpPriceValue = 1e8;
    bytes32[] public closedTradeHashes;
    ITradingReader.Position[] internal positions;

    constructor(address alpToken_, address marginToken_, address pairBaseToken_) {
        alpToken = alpToken_;
        marginToken = marginToken_;
        pairBaseToken = pairBaseToken_;
    }

    function ALP() external view returns (address) {
        return alpToken;
    }

    function coolingDuration() external pure returns (uint256) {
        return 0;
    }

    function lastMintedTimestamp(address) external pure returns (uint256) {
        return 0;
    }

    function alpPrice() external view returns (uint256) {
        return alpPriceValue;
    }

    function setAlpPrice(uint256 price) external {
        alpPriceValue = price;
    }

    function mintAlp(address, uint256 amount, uint256, bool) external returns (uint256 alpOut) {
        MockERC20(alpToken).mint(msg.sender, amount);
        return amount;
    }

    function burnAlp(address, uint256 alpAmount, uint256, address) external pure returns (uint256 tokenOutAmount) {
        return alpAmount;
    }

    function openMarketTrade(IAsterDiamond.OpenDataInput calldata) external {}

    function addMargin(bytes32, uint96) external {}

    function closeTrade(bytes32 tradeHash) external {
        closedTradeHashes.push(tradeHash);
    }

    function closedCount() external view returns (uint256) {
        return closedTradeHashes.length;
    }

    function closedAt(uint256 index) external view returns (bytes32) {
        return closedTradeHashes[index];
    }

    function setShortPosition(
        bytes32 tradeHash,
        uint96 margin,
        uint80 qty,
        uint64 entryPrice,
        int256 fundingFee,
        uint96 holdingFee
    ) external {
        positions.push(
            ITradingReader.Position({
                positionHash: tradeHash,
                pair: "BTCB/USDT",
                pairBase: pairBaseToken,
                marginToken: marginToken,
                isLong: false,
                margin: margin,
                qty: qty,
                entryPrice: entryPrice,
                stopLoss: 0,
                takeProfit: 0,
                openFee: 0,
                executionFee: 0,
                fundingFee: fundingFee,
                timestamp: 0,
                holdingFee: holdingFee
            })
        );
    }

    function getPositionsV2(address, address) external view returns (ITradingReader.Position[] memory) {
        return positions;
    }
}

contract InvestorProtectionTest is Test {
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

    function testTotalAssetsIncludesHedgeMarginPnlAndFees() public {
        MockERC20 asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        MockERC20 alp = new MockERC20("ALP", "ALP", 18);
        MockLpPair pair = new MockLpPair(address(base), address(asset));
        MockVaultOracle oracle = new MockVaultOracle(address(pair), 1, 90e18);
        MockHedgeDiamond diamond = new MockHedgeDiamond(address(alp), address(asset), address(base));

        pair.setReserves(1e18, 1e18);
        diamond.setShortPosition(bytes32("short-1"), 100e18, uint80(1e10), uint64(100e8), int256(5e18), 2e18);

        EngineVault vault = _deployVault(asset, base, diamond, address(pair), address(oracle), false, 200, 0);

        assertEq(vault.totalAssets(), 103e18);
    }

    function testVirtualSharesDefendDonationInflation() public {
        MockERC20 asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        MockERC20 alp = new MockERC20("ALP", "ALP", 18);
        MockHedgeDiamond diamond = new MockHedgeDiamond(address(alp), address(asset), address(base));

        EngineVault vault = _deployVault(asset, base, diamond, address(0), address(0), false, 200, 0);

        address attacker = address(0xA11CE);
        address victim = address(0xB0B);
        asset.mint(attacker, 1e18);
        asset.mint(victim, 1e18);

        vm.startPrank(attacker);
        asset.approve(address(vault), 1e18);
        vault.deposit(1e18, attacker);
        vm.stopPrank();

        asset.mint(address(vault), 1_000_000e18);

        vm.startPrank(victim);
        asset.approve(address(vault), 1e18);
        uint256 victimShares = vault.deposit(1e18, victim);
        vm.stopPrank();

        assertGt(victimShares, 0);
        assertGt(victimShares, 4e17);
    }

    function testDepositRevertsWhenPriceGuardBroken() public {
        MockERC20 asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        MockERC20 alp = new MockERC20("ALP", "ALP", 18);
        MockLpPair pair = new MockLpPair(address(base), address(asset));
        MockVaultOracle oracle = new MockVaultOracle(address(pair), 1, 1e18);
        MockHedgeDiamond diamond = new MockHedgeDiamond(address(alp), address(asset), address(base));
        EngineVault vault = _deployVault(asset, base, diamond, address(pair), address(oracle), false, 200, 0);

        pair.setReserves(1e18, 5e17);
        asset.mint(address(this), 100e18);
        asset.approve(address(vault), 100e18);

        vm.expectRevert("PRICE_GUARD");
        vault.deposit(100e18, address(this));
    }

    function testPartialHedgeCloseOnlyClosesNeededPositions() public {
        MockERC20 asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        MockERC20 alp = new MockERC20("ALP", "ALP", 18);
        MockLpPair pair = new MockLpPair(address(base), address(asset));
        MockVaultOracle oracle = new MockVaultOracle(address(pair), 1, 1e18);
        MockHedgeDiamond diamond = new MockHedgeDiamond(address(alp), address(asset), address(base));
        EngineVault vault = _deployVault(asset, base, diamond, address(pair), address(oracle), true, 0, 10000);

        pair.setReserves(1e18, 1e18);
        pair.setTotalSupply(1e18);
        pair.setBalance(address(vault), 6e17);

        diamond.setShortPosition(bytes32("short-a"), 60e18, uint80(6e9), uint64(100e8), 0, 0);
        diamond.setShortPosition(bytes32("short-b"), 60e18, uint80(6e9), uint64(100e8), 0, 0);

        oracle.setSnapshotCount(1);
        oracle.setVolatilityBps(200);
        vault.cycle();

        assertEq(diamond.closedCount(), 1);
        assertEq(diamond.closedAt(0), bytes32("short-a"));
    }
}
