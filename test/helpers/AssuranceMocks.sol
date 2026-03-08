pragma solidity ^0.8.24;

import {ITradingReader} from "../../contracts/interfaces/ITradingReader.sol";
import {IAsterDiamond} from "../../contracts/interfaces/IAsterDiamond.sol";
import {VolatilityOracle} from "../../contracts/core/VolatilityOracle.sol";
import {MockERC20} from "../MockERC20.sol";

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
    uint256 public cooldownValue;
    uint256 public lastMintedValue;
    bool public revertOnCloseTrade;
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

    function coolingDuration() external view returns (uint256) {
        return cooldownValue;
    }

    function setCooldown(uint256 cooldown) external {
        cooldownValue = cooldown;
    }

    function lastMintedTimestamp(address) external view returns (uint256) {
        return lastMintedValue;
    }

    function setLastMintedTimestamp(uint256 value) external {
        lastMintedValue = value;
    }

    function alpPrice() external view returns (uint256) {
        return alpPriceValue;
    }

    function setAlpPrice(uint256 price) external {
        alpPriceValue = price;
    }

    function setRevertOnCloseTrade(bool shouldRevert) external {
        revertOnCloseTrade = shouldRevert;
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
        if (revertOnCloseTrade) {
            revert("CLOSE_BLOCKED");
        }
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

    function getPositionByHashV2(bytes32 tradeHash) external view returns (ITradingReader.Position memory) {
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].positionHash == tradeHash) {
                return positions[i];
            }
        }
        revert("POSITION_NOT_FOUND");
    }

    function getPositionsV2(address, address) external view returns (ITradingReader.Position[] memory) {
        return positions;
    }
}
