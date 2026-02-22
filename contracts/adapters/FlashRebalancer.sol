pragma solidity ^0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";
import {IPancakePairV2} from "../interfaces/IPancakePairV2.sol";
import {PancakeLibrary} from "../libs/PancakeLibrary.sol";

contract FlashRebalancer {
    address public immutable factory;
    address public immutable pair;
    address public immutable vault;

    constructor(address factory_, address pair_, address vault_) {
        factory = factory_;
        pair = pair_;
        vault = vault_;
    }

    struct RebalanceParams {
        uint256 borrowAmount;
        bool borrowToken0;
    }

    function executeFlashRebalance(RebalanceParams calldata params) external {
        require(msg.sender == vault, "ONLY_VAULT");
        uint256 amount0Out = params.borrowToken0 ? params.borrowAmount : 0;
        uint256 amount1Out = params.borrowToken0 ? 0 : params.borrowAmount;
        IPancakePairV2(pair).swap(amount0Out, amount1Out, address(this), abi.encode(params));
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        require(msg.sender == pair, "INVALID_PAIR");
        require(sender == address(this), "INVALID_SENDER");

        RebalanceParams memory params = abi.decode(data, (RebalanceParams));
        require(params.borrowAmount == (params.borrowToken0 ? amount0 : amount1), "AMOUNT_MISMATCH");

        address token0 = IPancakePairV2(pair).token0();
        address token1 = IPancakePairV2(pair).token1();

        address[] memory path = new address[](2);
        uint256 repayAmount;

        if (params.borrowToken0) {
            path[0] = token1;
            path[1] = token0;
            repayAmount = PancakeLibrary.getAmountsIn(factory, amount0, path)[0];
            IERC20(token1).transfer(msg.sender, repayAmount);
        } else {
            path[0] = token0;
            path[1] = token1;
            repayAmount = PancakeLibrary.getAmountsIn(factory, amount1, path)[0];
            IERC20(token0).transfer(msg.sender, repayAmount);
        }
    }
}
