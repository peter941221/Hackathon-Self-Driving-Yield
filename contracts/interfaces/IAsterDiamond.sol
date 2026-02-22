pragma solidity ^0.8.24;

interface IAsterDiamond {
    struct OpenDataInput {
        address pairBase;
        bool isLong;
        address tokenIn;
        uint256 amountIn;
        uint256 qty;
        uint256 price;
        uint256 stopLoss;
        uint256 takeProfit;
        uint256 broker;
    }

    function openMarketTrade(OpenDataInput calldata data) external;

    function closeTrade(bytes32 tradeHash) external;

    function addMargin(bytes32 tradeHash, uint256 amount) external;

    function mintAlp(address tokenIn, uint256 amount, uint256 minAlp) external returns (uint256 alpOut);

    function burnAlp(address tokenOut, uint256 alpAmount, uint256 minOut) external returns (uint256 tokenOutAmount);

    function ALP() external view returns (address);

    function coolingDuration() external view returns (uint256);

    function lastMintedTimestamp() external view returns (uint256);

    function getAlpNav() external view returns (uint256);

    // P0 subset; extend after ABI confirmation.
}
