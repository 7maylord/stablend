// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CreditScore is Ownable {
    mapping(address => uint256) public creditScores;
    mapping(address => uint256) public transactionCounts;

    event CreditScoreUpdated(address indexed user, uint256 score);

    constructor() Ownable(msg.sender) {}

    // Mock function for MVP; in production, updated by off-chain script
    function updateCreditScore(address user, uint256 transactionCount) external onlyOwner {
        transactionCounts[user] += transactionCount;
        uint256 score = calculateScore(transactionCount);
        creditScores[user] = score;
        emit CreditScoreUpdated(user, score);
    }

    function getCreditScore(address user) external view returns (uint256) {
        return creditScores[user] > 0 ? creditScores[user] : 500; // Default score
    }

    function calculateScore(uint256 transactionCount) internal pure returns (uint256) {
        // Higher transactions = better score
        if (transactionCount >= 100) return 900;
        if (transactionCount >= 50) return 700;
        if (transactionCount >= 10) return 500;
        return 300;
    }
}
