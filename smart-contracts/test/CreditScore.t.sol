// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CreditScore.sol";

contract CreditScoreTest is Test {
    CreditScore creditScore;
    address admin = address(this);
    address user1 = address(0x123);
    address nonOwner = address(0x456);

    function setUp() public {
        creditScore = new CreditScore();
    }

    function testUpdateCreditScore() public {
        uint256 transactionCount = 50;
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit CreditScore.CreditScoreUpdated(user1, 700); // 50 transactions = 700 score
        creditScore.updateCreditScore(user1, transactionCount);

        assertEq(creditScore.getCreditScore(user1), 700, "Incorrect credit score");
    }

    function testDefaultCreditScore() public {
        assertEq(creditScore.getCreditScore(user1), 500, "Incorrect default score");
    }

    function test_RevertUpdateScoreNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        creditScore.updateCreditScore(user1, 800);
    }

    function testCalculateScore() public {
        vm.prank(admin);
        
        // Test different transaction counts
        creditScore.updateCreditScore(user1, 5);
        assertEq(creditScore.getCreditScore(user1), 300, "Low transaction count should give 300");
        
        creditScore.updateCreditScore(user1, 15);
        assertEq(creditScore.getCreditScore(user1), 500, "Medium transaction count should give 500");
        
        creditScore.updateCreditScore(user1, 60);
        assertEq(creditScore.getCreditScore(user1), 700, "High transaction count should give 700");
        
        creditScore.updateCreditScore(user1, 150);
        assertEq(creditScore.getCreditScore(user1), 900, "Very high transaction count should give 900");
    }
}