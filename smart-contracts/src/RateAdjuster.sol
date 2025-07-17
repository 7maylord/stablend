// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CreditScore.sol";

contract RateAdjuster is Ownable {
    CreditScore public creditScoreContract;
    mapping(address => uint256) public userRates;
    uint256 public baseRate = 500; // 5% in basis points
    address public chainlinkFunctionAddress; // Mocked as owner for testnet

    event RateUpdated(address indexed user, uint256 newRate);

    constructor(address _creditScoreContract, address _chainlinkFunctionAddress) Ownable(msg.sender) {
        creditScoreContract = CreditScore(_creditScoreContract);
        chainlinkFunctionAddress = _chainlinkFunctionAddress; // Set to owner for testnet
    }

    function updateUserRate(address user, uint256 newRate) external {
        require(msg.sender == chainlinkFunctionAddress || msg.sender == owner(), "Only Chainlink or owner");
        require(newRate <= 5000, "Rate too high"); // Cap at 50%
        uint256 creditScore = creditScoreContract.getCreditScore(user);
        uint256 adjustedRate = baseRate + (newRate * (1000 - creditScore)) / 1000;
        userRates[user] = adjustedRate;
        emit RateUpdated(user, adjustedRate);
    }

    function getUserRate(address user) external view returns (uint256) {
        return userRates[user] == 0 ? baseRate : userRates[user];
    }
}
