// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CreditScore.sol";

contract RateAdjuster is Ownable {
    CreditScore public creditScoreContract;
    uint256 public baseRate = 500; // Default 5% in basis points
    mapping(address => uint256) public userRates;
    
    event RateUpdated(address indexed user, uint256 newRate);
    
    constructor(address _creditScoreContract) Ownable(msg.sender) {
        creditScoreContract = CreditScore(_creditScoreContract);
    }
    
    // Mock Chainlink oracle function for MVP
    function updateUserRate(address user, uint256 newRate) external onlyOwner {
        // In production, called by Chainlink with AI model output
        require(newRate <= 5000, "Rate too high"); // Cap at 50%
        uint256 creditScore = creditScoreContract.getCreditScore(user);
        uint256 adjustedRate = baseRate + (newRate * (1000 - creditScore)) / 1000; // Scale by credit score
        userRates[user] = adjustedRate;
        emit RateUpdated(user, adjustedRate);
    }
    
    function getUserRate(address user) external view returns (uint256) {
        return userRates[user] > 0 ? userRates[user] : baseRate;
    }
}