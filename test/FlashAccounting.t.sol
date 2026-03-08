pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EngineVault} from "../contracts/core/EngineVault.sol";
import {VolatilityOracle} from "../contracts/core/VolatilityOracle.sol";
import {IERC20} from "../contracts/interfaces/IERC20.sol";
import {MockLpPair} from "./helpers/AssuranceMocks.sol";

contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "BAL");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "ALLOW");
        allowance[from][msg.sender] = allowed - amount;
        require(balanceOf[from] >= amount, "BAL");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract EngineVaultHarness is EngineVault {
    constructor(Addresses memory addresses, Config memory config) EngineVault(addresses, config) {}

    function totalAssetsExcludingBorrowedBase(uint256 borrowedBaseAmount) external view returns (uint256) {
        (uint256 alpValue, uint256 lpValue, uint256 cashValue) = _getPortfolioValues(borrowedBaseAmount);
        return alpValue + lpValue + cashValue + _getHedgeAccountValue();
    }
}

contract FlashAccountingTest is Test {
    function testFlashBorrowedBaseExcluded() public {
        MockERC20 asset = new MockERC20();
        MockERC20 base = new MockERC20();
        base.mint(address(this), 100e18);

        MockLpPair pair = new MockLpPair(address(base), address(asset));
        pair.setReserves(1e18, 1e18);
        EngineVaultHarness vault = new EngineVaultHarness(
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
                minCycleInterval: 60,
                rebalanceThresholdBps: 500,
                deltaBandBps: 200,
                profitBountyBps: 1000,
                maxBountyBps: 50,
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

        base.transfer(address(vault), 100e18);

        assertEq(vault.totalAssetsExcludingBorrowedBase(40e18), 60e18);
    }

    function testFlashBorrowedBaseCapsAtZero() public {
        MockERC20 asset = new MockERC20();
        MockERC20 base = new MockERC20();
        base.mint(address(this), 50e18);

        MockLpPair pair = new MockLpPair(address(base), address(asset));
        pair.setReserves(1e18, 1e18);
        EngineVaultHarness vault = new EngineVaultHarness(
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
                minCycleInterval: 60,
                rebalanceThresholdBps: 500,
                deltaBandBps: 200,
                profitBountyBps: 1000,
                maxBountyBps: 50,
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

        base.transfer(address(vault), 50e18);

        assertEq(vault.totalAssetsExcludingBorrowedBase(80e18), 0);
    }
}
