//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

//if the price is stagnant for 3 hours, we want the stable coin protocol to stop
library OracleLib {
    error OracleLib__StagnantPrice();
    // 3 * 60 * 60 = 10800 seconds

    uint256 private constant TIMEOUT = 3 hours;

    function stagnantCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        //Getting the return variables from latestRoundData(), which includes the last updated timestamp
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();
        //Calculating how long its been since the last price update
        uint256 secondsDifference = block.timestamp - updatedAt;
        //If it's been longer then 3 hours, revert
        if (secondsDifference > TIMEOUT) {
            revert OracleLib__StagnantPrice();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
