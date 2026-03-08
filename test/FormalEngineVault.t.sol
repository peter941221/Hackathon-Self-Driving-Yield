pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EngineVault} from "../contracts/core/EngineVault.sol";
import {IERC20} from "../contracts/interfaces/IERC20.sol";
import {VolatilityOracle} from "../contracts/core/VolatilityOracle.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockVaultOracle, MockLpPair, MockHedgeDiamond} from "./helpers/AssuranceMocks.sol";

contract EngineVaultFormalHarness is EngineVault {
    constructor(Addresses memory addresses, Config memory config) EngineVault(addresses, config) {}

    function totalAssetsExcludingBorrowedBase(uint256 borrowedBaseAmount) external view returns (uint256) {
        (uint256 alpValue, uint256 lpValue, uint256 cashValue) = _getPortfolioValues(borrowedBaseAmount);
        return alpValue + lpValue + cashValue + _getHedgeAccountValue();
    }
}

contract EngineVaultFormalTest is Test {
    uint256 internal constant MAX_FORMAL_ASSETS = 1e24;

    function _assumePositiveReasonableAmount(uint256 amount) internal {
        vm.assume(amount > 0);
        vm.assume(amount <= MAX_FORMAL_ASSETS);
    }

    function _assumeReasonableAmount(uint256 amount) internal {
        vm.assume(amount <= MAX_FORMAL_ASSETS);
    }

    function _deployIsolatedVault() internal returns (EngineVaultFormalHarness vault, MockERC20 asset) {
        asset = new MockERC20("USDT", "USDT", 18);
        vault = new EngineVaultFormalHarness(
            EngineVault.Addresses({
                asset: IERC20(address(asset)),
                asterDiamond: address(0),
                pancakeFactory: address(0),
                v2Pair: address(0),
                pairBase: address(0),
                pairQuote: address(0),
                bnbUsdtPair: address(0),
                volatilityOracle: VolatilityOracle(address(0)),
                flashPair: address(0)
            }),
            EngineVault.Config({
                enableExternalCalls: false,
                minCycleInterval: 0,
                rebalanceThresholdBps: 500,
                deltaBandBps: 200,
                profitBountyBps: 0,
                maxBountyBps: 0,
                bufferCapBps: 2000,
                calmAlpBps: 4000,
                calmLpBps: 5700,
                normalAlpBps: 6000,
                normalLpBps: 3700,
                stormAlpBps: 8000,
                stormLpBps: 1700,
                safeCycleThreshold: 3,
                maxGasPrice: 0,
                swapSlippageBps: 50
            })
        );
    }

    function _deployPriceGuardVault()
        internal
        returns (EngineVaultFormalHarness vault, MockERC20 asset, MockVaultOracle oracle, MockLpPair pair)
    {
        asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        pair = new MockLpPair(address(base), address(asset));
        oracle = new MockVaultOracle(address(pair), 1, 1e18);
        pair.setReserves(1e18, 5e17);

        vault = new EngineVaultFormalHarness(
            EngineVault.Addresses({
                asset: IERC20(address(asset)),
                asterDiamond: address(0),
                pancakeFactory: address(0),
                v2Pair: address(pair),
                pairBase: address(base),
                pairQuote: address(asset),
                bnbUsdtPair: address(0),
                volatilityOracle: VolatilityOracle(address(oracle)),
                flashPair: address(0)
            }),
            EngineVault.Config({
                enableExternalCalls: false,
                minCycleInterval: 0,
                rebalanceThresholdBps: 500,
                deltaBandBps: 200,
                profitBountyBps: 0,
                maxBountyBps: 0,
                bufferCapBps: 2000,
                calmAlpBps: 4000,
                calmLpBps: 5700,
                normalAlpBps: 6000,
                normalLpBps: 3700,
                stormAlpBps: 8000,
                stormLpBps: 1700,
                safeCycleThreshold: 3,
                maxGasPrice: 0,
                swapSlippageBps: 50
            })
        );
    }

    function _deployOnlyUnwindVault()
        internal
        returns (
            EngineVaultFormalHarness vault,
            MockERC20 asset,
            MockERC20 alp,
            MockLpPair pair,
            MockVaultOracle oracle,
            MockHedgeDiamond diamond
        )
    {
        asset = new MockERC20("USDT", "USDT", 18);
        MockERC20 base = new MockERC20("BTCB", "BTCB", 18);
        alp = new MockERC20("ALP", "ALP", 18);
        pair = new MockLpPair(address(base), address(asset));
        pair.setReserves(1e18, 5e17);
        oracle = new MockVaultOracle(address(pair), 1, 1e18);
        diamond = new MockHedgeDiamond(address(alp), address(asset), address(base));

        vault = new EngineVaultFormalHarness(
            EngineVault.Addresses({
                asset: IERC20(address(asset)),
                asterDiamond: address(diamond),
                pancakeFactory: address(0),
                v2Pair: address(pair),
                pairBase: address(base),
                pairQuote: address(asset),
                bnbUsdtPair: address(0),
                volatilityOracle: VolatilityOracle(address(oracle)),
                flashPair: address(0)
            }),
            EngineVault.Config({
                enableExternalCalls: true,
                minCycleInterval: 0,
                rebalanceThresholdBps: 50,
                deltaBandBps: 200,
                profitBountyBps: 0,
                maxBountyBps: 0,
                bufferCapBps: 10000,
                calmAlpBps: 5000,
                calmLpBps: 4500,
                normalAlpBps: 5000,
                normalLpBps: 4500,
                stormAlpBps: 5000,
                stormLpBps: 4500,
                safeCycleThreshold: 2,
                maxGasPrice: 0,
                swapSlippageBps: 50
            })
        );
    }

    function _deployFlashAccountingVault()
        internal
        returns (EngineVaultFormalHarness vault, MockERC20 asset, MockERC20 base)
    {
        asset = new MockERC20("USDT", "USDT", 18);
        base = new MockERC20("BTCB", "BTCB", 18);
        MockLpPair pair = new MockLpPair(address(base), address(asset));
        pair.setReserves(1e18, 1e18);

        vault = new EngineVaultFormalHarness(
            EngineVault.Addresses({
                asset: IERC20(address(asset)),
                asterDiamond: address(0),
                pancakeFactory: address(0),
                v2Pair: address(pair),
                pairBase: address(base),
                pairQuote: address(asset),
                bnbUsdtPair: address(0),
                volatilityOracle: VolatilityOracle(address(0)),
                flashPair: address(0)
            }),
            EngineVault.Config({
                enableExternalCalls: false,
                minCycleInterval: 0,
                rebalanceThresholdBps: 500,
                deltaBandBps: 200,
                profitBountyBps: 0,
                maxBountyBps: 0,
                bufferCapBps: 2000,
                calmAlpBps: 4000,
                calmLpBps: 5700,
                normalAlpBps: 6000,
                normalLpBps: 3700,
                stormAlpBps: 8000,
                stormLpBps: 1700,
                safeCycleThreshold: 3,
                maxGasPrice: 0,
                swapSlippageBps: 50
            })
        );
    }

    function check_totalAssetsEqualsCashWithoutExternals(uint256 cash) public {
        _assumeReasonableAmount(cash);

        (EngineVaultFormalHarness vault, MockERC20 asset) = _deployIsolatedVault();
        asset.mint(address(vault), cash);

        assert(vault.totalAssets() == cash);
    }

    function check_emptyVaultPreviewDepositIsOneToOne(uint256 assets) public {
        _assumePositiveReasonableAmount(assets);

        (EngineVaultFormalHarness vault, MockERC20 asset) = _deployIsolatedVault();
        asset;
        assert(vault.previewDeposit(assets) == assets);
    }

    function check_emptyVaultPreviewRedeemIsZero(uint256 shares) public {
        _assumeReasonableAmount(shares);

        (EngineVaultFormalHarness vault, MockERC20 asset) = _deployIsolatedVault();
        asset;
        assert(vault.previewRedeem(shares) == 0);
    }

    function check_cyclePaysNoBountyWithoutProfit(uint256 assets) public {
        _assumePositiveReasonableAmount(assets);

        (EngineVaultFormalHarness vault, MockERC20 asset) = _deployIsolatedVault();
        address caller = address(0xBEEF);

        asset.mint(address(this), assets);
        asset.approve(address(vault), assets);
        vault.deposit(assets, address(this));

        uint256 beforeCallerBalance = asset.balanceOf(caller);
        vm.prank(caller);
        vault.cycle();
        uint256 afterCallerBalance = asset.balanceOf(caller);

        assert(afterCallerBalance == beforeCallerBalance);
    }

    function check_priceGuardRejectsBrokenMark(uint256 assets) public {
        _assumePositiveReasonableAmount(assets);

        (EngineVaultFormalHarness vault, MockERC20 asset,,) = _deployPriceGuardVault();
        asset.mint(address(this), assets);
        asset.approve(address(vault), assets);

        (bool ok,) = address(vault).call(abi.encodeWithSignature("deposit(uint256,address)", assets, address(this)));
        assert(!ok);
    }

    function check_onlyUnwindBlocksFreshExposure(uint256 cash) public {
        _assumePositiveReasonableAmount(cash);

        (EngineVaultFormalHarness vault, MockERC20 asset, MockERC20 alp, MockLpPair pair,,) = _deployOnlyUnwindVault();
        asset.mint(address(vault), cash);

        vault.cycle();

        assert(uint256(vault.riskMode()) == uint256(EngineVault.RiskMode.ONLY_UNWIND));
        assert(alp.balanceOf(address(vault)) == 0);
        assert(pair.balanceOf(address(vault)) == 0);
    }

    function check_onlyUnwindRecoversAfterTwoSafeCycles() public {
        (EngineVaultFormalHarness vault, MockERC20 asset,, MockLpPair pair, MockVaultOracle oracle,) = _deployOnlyUnwindVault();
        asset.mint(address(vault), 1e18);

        vault.cycle();
        assert(uint256(vault.riskMode()) == uint256(EngineVault.RiskMode.ONLY_UNWIND));

        pair.setReserves(1e18, 1e18);
        oracle.setTwapPrice(1e18);

        vault.cycle();
        assert(uint256(vault.riskMode()) == uint256(EngineVault.RiskMode.ONLY_UNWIND));
        assert(vault.safeCycleCount() == 1);

        vault.cycle();
        assert(uint256(vault.riskMode()) == uint256(EngineVault.RiskMode.NORMAL));
        assert(vault.safeCycleCount() == 0);
    }

    function check_flashBorrowedBaseExcludedWhenUnderwater(uint16 baseBalance, uint16 borrowed) public {
        _assumeReasonableAmount(baseBalance);
        _assumeReasonableAmount(borrowed);
        vm.assume(borrowed > baseBalance);

        (EngineVaultFormalHarness vault,, MockERC20 base) = _deployFlashAccountingVault();
        base.mint(address(vault), baseBalance);

        assert(vault.totalAssetsExcludingBorrowedBase(borrowed) == 0);
    }
}
