pragma solidity ^0.8.24;

import {IERC20} from "../../contracts/interfaces/IERC20.sol";
import {VolatilityOracle} from "../../contracts/core/VolatilityOracle.sol";

contract MockPricePair {
    address public token0;
    address public token1;
    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimestampLast;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setReserves(uint112 reserve0_, uint112 reserve1_) external {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
        blockTimestampLast = uint32(block.timestamp);
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }
}

contract MockPancakeFactory {
    mapping(address => mapping(address => address)) public getPair;

    function setPair(address tokenA, address tokenB, address pair) external {
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
    }
}

interface IPancakeCallee {
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

contract MockPancakePairLocking {
    address public token0;
    address public token1;

    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
        blockTimestampLast = uint32(block.timestamp);
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

    function setReserves(uint112 r0, uint112 r1) external {
        reserve0 = r0;
        reserve1 = r1;
        blockTimestampLast = uint32(block.timestamp);
    }

    function mintLp(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        uint256 liquidity = balanceOf[address(this)];
        require(liquidity > 0, "ZERO_BURN");

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "ZERO_OUT");

        balanceOf[address(this)] = 0;
        totalSupply -= liquidity;

        require(IERC20(token0).transfer(to, amount0), "T0");
        require(IERC20(token1).transfer(to, amount1), "T1");

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, "ZERO_OUT");
        require(amount0Out < uint256(reserve0) && amount1Out < uint256(reserve1), "INSUFFICIENT_LIQ");

        if (amount0Out > 0) {
            require(IERC20(token0).transfer(to, amount0Out), "OUT0");
        }
        if (amount1Out > 0) {
            require(IERC20(token1).transfer(to, amount1Out), "OUT1");
        }

        if (data.length > 0) {
            IPancakeCallee(to).pancakeCall(msg.sender, amount0Out, amount1Out, data);
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0 > uint256(reserve0) - amount0Out ? balance0 - (uint256(reserve0) - amount0Out) : 0;
        uint256 amount1In = balance1 > uint256(reserve1) - amount1Out ? balance1 - (uint256(reserve1) - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "ZERO_IN");

        uint256 balance0Adjusted = balance0 * 1000 - amount0In * 2;
        uint256 balance1Adjusted = balance1 * 1000 - amount1In * 2;
        require(balance0Adjusted * balance1Adjusted >= uint256(reserve0) * uint256(reserve1) * 1000 * 1000, "K");

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp);
    }
}

contract MockPancakeRouter {
    address internal constant FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;

    function removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256, uint256, address to, uint256)
        external
        returns (uint256 amountA, uint256 amountB)
    {
        address pair = MockPancakeFactory(FACTORY).getPair(tokenA, tokenB);
        require(pair != address(0), "NO_PAIR");

        require(MockPancakePairLocking(pair).transferFrom(msg.sender, pair, liquidity), "LP");
        (uint256 amount0, uint256 amount1) = MockPancakePairLocking(pair).burn(to);

        if (tokenA == MockPancakePairLocking(pair).token0()) {
            amountA = amount0;
            amountB = amount1;
        } else {
            amountA = amount1;
            amountB = amount0;
        }
    }

    function addLiquidity(address, address, uint256, uint256, uint256, uint256, address, uint256)
        external
        pure
        returns (uint256, uint256, uint256)
    {
        revert("UNUSED");
    }

    function swapExactTokensForTokens(uint256, uint256, address[] calldata, address, uint256)
        external
        pure
        returns (uint256[] memory)
    {
        revert("UNUSED");
    }
}

contract MockVolOracleStorm {
    address public pair;
    uint8 public minSamples;
    uint8 public snapshotCount;
    uint256 public twapPrice1e18;

    constructor(address pair_, uint256 twapPrice1e18_) {
        pair = pair_;
        minSamples = 1;
        snapshotCount = 1;
        twapPrice1e18 = twapPrice1e18_;
    }

    function recordSnapshot() external {
        snapshotCount++;
    }

    function getRegime() external pure returns (VolatilityOracle.Regime) {
        return VolatilityOracle.Regime.STORM;
    }

    function getVolatilityBps() external pure returns (uint256) {
        return 400;
    }

    function getTwapPrice1e18() external view returns (uint256) {
        return twapPrice1e18;
    }
}
