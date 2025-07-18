// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IChainlinkOracle.sol";

contract MockChainlinkFeed is AggregatorV3Interface {
    int256 public price = 80000000; // $0.80 in 8 decimals
    uint8 public decimals_ = 8;
    string public description_ = "MNT / USD";
    uint256 public version_ = 1;

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, price, block.timestamp, block.timestamp, 1);
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, price, block.timestamp, block.timestamp, _roundId);
    }

    function decimals() external view returns (uint8) {
        return decimals_;
    }

    function description() external view returns (string memory) {
        return description_;
    }

    function version() external view returns (uint256) {
        return version_;
    }

    // Function to update price for testing
    function setPrice(int256 newPrice) external {
        price = newPrice;
    }
} 