// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CreditScore} from "../src/CreditScore.sol";
import {RateAdjuster} from "../src/RateAdjuster.sol";

contract RateAdjusterTest is Test {
    CreditScore public creditScore;
    RateAdjuster public rateAdjuster;
    
    address public owner;
    address public user1;
    address public user2;
    address public chainlinkFunction;
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        chainlinkFunction = makeAddr("chainlinkFunction");
        
        vm.startPrank(owner);
        creditScore = new CreditScore();
        rateAdjuster = new RateAdjuster(address(creditScore), chainlinkFunction);
        vm.stopPrank();
    }
    
    function test_Constructor() public {
        assertEq(address(rateAdjuster.creditScoreContract()), address(creditScore));
        assertEq(rateAdjuster.chainlinkFunctionAddress(), chainlinkFunction);
        assertEq(rateAdjuster.baseRate(), 500); // 5%
    }
    
    function test_UpdateUserRateByOwner() public {
        vm.startPrank(owner);
        rateAdjuster.updateUserRate(user1, 1000); // 10%
        vm.stopPrank();
        
        uint256 userRate = rateAdjuster.getUserRate(user1);
        // With default credit score 500: 500 + (1000 * (1000 - 500)) / 1000 = 500 + 500 = 1000
        assertEq(userRate, 1000);
    }
    
    function test_UpdateUserRateByChainlinkFunction() public {
        vm.startPrank(chainlinkFunction);
        rateAdjuster.updateUserRate(user1, 800); // 8%
        vm.stopPrank();
        
        uint256 userRate = rateAdjuster.getUserRate(user1);
        // With default credit score 500: 500 + (800 * (1000 - 500)) / 1000 = 500 + 400 = 900
        assertEq(userRate, 900);
    }
    
    function test_RevertUpdateUserRateByUnauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert("Only Chainlink or owner");
        rateAdjuster.updateUserRate(user2, 1000);
        vm.stopPrank();
    }
    
    function test_RevertUpdateUserRateTooHigh() public {
        vm.startPrank(owner);
        vm.expectRevert("Rate too high");
        rateAdjuster.updateUserRate(user1, 6000); // 60% (above 50% cap)
        vm.stopPrank();
    }
    
    function test_GetUserRateWithCreditScore() public {
        // Set credit score for user1 to 800 (high credit score)
        vm.startPrank(owner);
        creditScore.updateCreditScore(user1, 100); // 100 transactions = 900 score
        rateAdjuster.updateUserRate(user1, 1000); // 10% base rate
        vm.stopPrank();
        
        uint256 userRate = rateAdjuster.getUserRate(user1);
        // Expected: 500 + (1000 * (1000 - 900)) / 1000 = 500 + 100 = 600 (6%)
        assertEq(userRate, 600);
    }
    
    function test_GetUserRateWithLowCreditScore() public {
        // Set credit score for user2 to 300 (low credit score)
        vm.startPrank(owner);
        creditScore.updateCreditScore(user2, 5); // 5 transactions = 300 score
        rateAdjuster.updateUserRate(user2, 1000); // 10% base rate
        vm.stopPrank();
        
        uint256 userRate = rateAdjuster.getUserRate(user2);
        // Expected: 500 + (1000 * (1000 - 300)) / 1000 = 500 + 700 = 1200 (12%)
        assertEq(userRate, 1200);
    }
    
    function test_GetUserRateDefault() public {
        uint256 userRate = rateAdjuster.getUserRate(user1);
        assertEq(userRate, 500); // Default base rate
    }
    
    function test_UpdateUserRateEvent() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit RateAdjuster.RateUpdated(user1, 1000);
        rateAdjuster.updateUserRate(user1, 1000);
        vm.stopPrank();
    }
    
    function test_MultipleUserRates() public {
        vm.startPrank(owner);
        
        // Set different rates for different users
        rateAdjuster.updateUserRate(user1, 800);
        rateAdjuster.updateUserRate(user2, 1200);
        
        vm.stopPrank();
        
        // user1: 500 + (800 * (1000 - 500)) / 1000 = 500 + 400 = 900
        // user2: 500 + (1200 * (1000 - 500)) / 1000 = 500 + 600 = 1100
        assertEq(rateAdjuster.getUserRate(user1), 900);
        assertEq(rateAdjuster.getUserRate(user2), 1100);
    }
    
    function test_UpdateExistingRate() public {
        vm.startPrank(owner);
        
        // Set initial rate
        rateAdjuster.updateUserRate(user1, 800);
        assertEq(rateAdjuster.getUserRate(user1), 900); // 500 + 400
        
        // Update rate
        rateAdjuster.updateUserRate(user1, 1000);
        assertEq(rateAdjuster.getUserRate(user1), 1000); // 500 + 500
        
        vm.stopPrank();
    }
    
    function test_EdgeCaseZeroRate() public {
        vm.startPrank(owner);
        rateAdjuster.updateUserRate(user1, 0);
        vm.stopPrank();
        
        uint256 userRate = rateAdjuster.getUserRate(user1);
        assertEq(userRate, 500); // Should return base rate when rate is 0
    }
    
    function test_EdgeCaseMaximumRate() public {
        vm.startPrank(owner);
        rateAdjuster.updateUserRate(user1, 5000); // Maximum allowed rate
        vm.stopPrank();
        
        uint256 userRate = rateAdjuster.getUserRate(user1);
        // 500 + (5000 * (1000 - 500)) / 1000 = 500 + 2500 = 3000
        assertEq(userRate, 3000);
    }
}