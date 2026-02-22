pragma solidity ^0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";
import {IAsterDiamond} from "../interfaces/IAsterDiamond.sol";

library Aster1001xAdapter {
    function openShort(
        address diamond,
        address pairBase,
        address tokenIn,
        uint256 marginAmount,
        uint256 qty,
        uint256 worstPrice
    ) internal {
        IAsterDiamond.OpenDataInput memory data = IAsterDiamond.OpenDataInput({
            pairBase: pairBase,
            isLong: false,
            tokenIn: tokenIn,
            amountIn: marginAmount,
            qty: qty,
            price: worstPrice,
            stopLoss: 0,
            takeProfit: 0,
            broker: 0
        });

        IERC20(tokenIn).approve(diamond, marginAmount);
        IAsterDiamond(diamond).openMarketTrade(data);
    }

    function closeTrade(address diamond, bytes32 tradeHash) internal {
        IAsterDiamond(diamond).closeTrade(tradeHash);
    }

    function addMargin(address diamond, bytes32 tradeHash, address tokenIn, uint256 amount) internal {
        IERC20(tokenIn).approve(diamond, amount);
        IAsterDiamond(diamond).addMargin(tradeHash, amount);
    }

    function getPositions(address diamond, address account)
        internal
        view
        returns (bytes32[] memory tradeHashes, uint256 totalQty)
    {
        (bool ok, bytes memory data) = diamond.staticcall(
            abi.encodeWithSignature("getPositionsV2(address)", account)
        );
        require(ok, "READER_CALL_FAIL");
        (tradeHashes, totalQty) = abi.decode(data, (bytes32[], uint256));
    }

    function getHedgeBaseQty(address diamond, address account) internal view returns (uint256 baseQty) {
        (, uint256 totalQty) = getPositions(diamond, account);
        baseQty = totalQty;
    }

    function usdToQty(uint256 usdAmount, uint256 price1e8) internal pure returns (uint256 qty1e10) {
        if (price1e8 == 0) {
            return 0;
        }
        qty1e10 = (usdAmount * 1e10) / price1e8;
    }
}
