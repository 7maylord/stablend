// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockMNT} from "../src/mocks/MockMNT.sol";
import {CreditScore} from "../src/CreditScore.sol";
import {RateAdjuster} from "../src/RateAdjuster.sol";
import {LendingMarket} from "../src/LendingMarket.sol";
import {AggregatorV3Interface} from "../src/interfaces/IChainlinkOracle.sol";

contract LendingMarketTest is Test {
    MockUSDC public mockUSDC;
    MockMNT public mockMNT;
    CreditScore public creditScore;
    RateAdjuster public rateAdjuster;
    LendingMarket public lendingMarket;
    
    address public deployer;
    address public user1;
    address public user2;
    address public liquidator;
    
    // Mock Chainlink feed address
    address public constant MOCK_CHAINLINK_FEED = address(0x1234567890123456789012345678901234567890);
    
    function setUp() public {
        deployer = makeAddr("deployer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        liquidator = makeAddr("liquidator");
        
        vm.startPrank(deployer);
        
        // Deploy contracts
        mockUSDC = new MockUSDC();
        mockMNT = new MockMNT();
        creditScore = new CreditScore();
        rateAdjuster = new RateAdjuster(address(creditScore), deployer);
        lendingMarket = new LendingMarket(
            address(mockUSDC),
            address(mockMNT),
            address(rateAdjuster),
            MOCK_CHAINLINK_FEED
        );
        
        // Mint initial tokens
        mockUSDC.mint(deployer, 1000000 * 10**6); // 1M USDC
        mockMNT.mint(deployer, 1000000 * 10**18); // 1M MNT
        
        // Distribute tokens to users
        mockUSDC.transfer(user1, 100000 * 10**6); // 100K USDC
        mockMNT.transfer(user1, 100000 * 10**18); // 100K MNT
        mockUSDC.transfer(user2, 100000 * 10**6); // 100K USDC
        mockMNT.transfer(user2, 100000 * 10**18); // 100K MNT
        mockUSDC.transfer(liquidator, 100000 * 10**6); // 100K USDC
        
        vm.stopPrank();
    }
    
    // Helper function to mock Chainlink price
    function mockChainlinkPrice(uint256 price) internal {
        vm.mockCall(
            MOCK_CHAINLINK_FEED,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(1), int256(price), uint256(block.timestamp), uint256(block.timestamp), uint80(1))
        );
    }
    
    function test_Deposit() public {
        uint256 depositAmount = 10000 * 10**6; // 10K USDC
        
        vm.startPrank(user1);
        mockUSDC.approve(address(lendingMarket), depositAmount);
        lendingMarket.deposit(depositAmount);
        vm.stopPrank();
        
        assertEq(lendingMarket.lenderBalances(user1), depositAmount);
        assertEq(lendingMarket.totalDeposits(), depositAmount);
    }
    
    function test_Withdraw() public {
        uint256 depositAmount = 10000 * 10**6; // 10K USDC
        uint256 withdrawAmount = 5000 * 10**6; // 5K USDC
        
        vm.startPrank(user1);
        mockUSDC.approve(address(lendingMarket), depositAmount);
        lendingMarket.deposit(depositAmount);
        
        uint256 balanceBefore = mockUSDC.balanceOf(user1);
        lendingMarket.withdraw(withdrawAmount);
        uint256 balanceAfter = mockUSDC.balanceOf(user1);
        vm.stopPrank();
        
        assertEq(balanceAfter - balanceBefore, withdrawAmount);
        assertEq(lendingMarket.lenderBalances(user1), depositAmount - withdrawAmount);
    }
    
    function test_Borrow() public {
        // Setup deposit first
        vm.startPrank(user1);
        uint256 depositAmount = 50000 * 10**6; // 50K USDC
        mockUSDC.approve(address(lendingMarket), depositAmount);
        lendingMarket.deposit(depositAmount);
        vm.stopPrank();
        
        // Mock MNT price at $0.80
        mockChainlinkPrice(80000000); // $0.80 with 8 decimals
        
        vm.startPrank(user2);
        uint256 borrowAmount = 10000 * 10**6; // 10K USDC
        uint256 collateralAmount = 20000 * 10**18; // 20K MNT (worth $16K at $0.80, 160% collateral ratio)
        
        mockMNT.approve(address(lendingMarket), collateralAmount);
        lendingMarket.borrow(borrowAmount, collateralAmount);
        vm.stopPrank();
        
        LendingMarket.Loan memory loan = lendingMarket.getLoanInfo(user2);
        assertEq(loan.amount, borrowAmount);
        assertEq(loan.collateral, collateralAmount);
        assertTrue(loan.isActive);
    }
    
    function test_Repay() public {
        // Setup deposit and borrow
        vm.startPrank(user1);
        uint256 depositAmount = 50000 * 10**6; // 50K USDC
        mockUSDC.approve(address(lendingMarket), depositAmount);
        lendingMarket.deposit(depositAmount);
        vm.stopPrank();
        
        mockChainlinkPrice(80000000); // $0.80
        
        vm.startPrank(user2);
        uint256 borrowAmount = 10000 * 10**6; // 10K USDC
        uint256 collateralAmount = 20000 * 10**18; // 20K MNT
        
        mockMNT.approve(address(lendingMarket), collateralAmount);
        lendingMarket.borrow(borrowAmount, collateralAmount);
        
        // Repay half the loan
        uint256 repayAmount = 5000 * 10**6; // 5K USDC
        mockUSDC.approve(address(lendingMarket), repayAmount);
        lendingMarket.repay(repayAmount);
        vm.stopPrank();
        
        LendingMarket.Loan memory loan = lendingMarket.getLoanInfo(user2);
        assertEq(loan.amount, borrowAmount - repayAmount);
    }
    
    function test_Liquidation() public {
        // Setup deposit
        vm.startPrank(user1);
        uint256 depositAmount = 50000 * 10**6; // 50K USDC
        mockUSDC.approve(address(lendingMarket), depositAmount);
        lendingMarket.deposit(depositAmount);
        vm.stopPrank();
        
        // Borrow with high collateral ratio
        mockChainlinkPrice(80000000); // $0.80
        
        vm.startPrank(user2);
        uint256 borrowAmount = 10000 * 10**6; // 10K USDC
        uint256 collateralAmount = 20000 * 10**18; // 20K MNT (worth $16K at $0.80, 160% collateral ratio)
        
        mockMNT.approve(address(lendingMarket), collateralAmount);
        lendingMarket.borrow(borrowAmount, collateralAmount);
        vm.stopPrank();
        
        // Price drops to $0.40 (undercollateralized - 20K MNT * $0.40 = $8K < $12.5K required for 125% threshold)
        mockChainlinkPrice(40000000); // $0.40
        
        // Liquidate the position
        vm.startPrank(liquidator);
        uint256 debtToRepay = lendingMarket.getTotalDebt(user2);
        mockUSDC.approve(address(lendingMarket), debtToRepay);
        lendingMarket.liquidate(user2);
        vm.stopPrank();
        
        // Check that loan is liquidated
        LendingMarket.Loan memory loan = lendingMarket.getLoanInfo(user2);
        assertFalse(loan.isActive);
    }
    
    function test_InterestAccrual() public {
        // Setup deposit
        vm.startPrank(user1);
        uint256 depositAmount = 50000 * 10**6; // 50K USDC
        mockUSDC.approve(address(lendingMarket), depositAmount);
        lendingMarket.deposit(depositAmount);
        vm.stopPrank();
        
        mockChainlinkPrice(80000000); // $0.80
        
        vm.startPrank(user2);
        uint256 borrowAmount = 10000 * 10**6; // 10K USDC
        uint256 collateralAmount = 20000 * 10**18; // 20K MNT
        
        mockMNT.approve(address(lendingMarket), collateralAmount);
        lendingMarket.borrow(borrowAmount, collateralAmount);
        vm.stopPrank();
        
        // Fast forward 30 days
        skip(30 days);
        
        // Check interest accrual
        uint256 totalDebt = lendingMarket.getTotalDebt(user2);
        assertGt(totalDebt, borrowAmount, "Interest should have accrued");
    }
    
    function test_CollateralRatio() public {
        // Setup deposit
        vm.startPrank(user1);
        uint256 depositAmount = 50000 * 10**6; // 50K USDC
        mockUSDC.approve(address(lendingMarket), depositAmount);
        lendingMarket.deposit(depositAmount);
        vm.stopPrank();
        
        mockChainlinkPrice(80000000); // $0.80
        
        vm.startPrank(user2);
        uint256 borrowAmount = 10000 * 10**6; // 10K USDC
        uint256 collateralAmount = 20000 * 10**18; // 20K MNT
        
        mockMNT.approve(address(lendingMarket), collateralAmount);
        lendingMarket.borrow(borrowAmount, collateralAmount);
        vm.stopPrank();
        
        uint256 collateralRatio = lendingMarket.getCollateralRatio(user2);
        // At $0.80, 20K MNT = $16K, borrowing $10K = 160% collateral ratio
        assertGt(collateralRatio, 150, "Collateral ratio should be above 150%");
    }
    
    function test_RevertInsufficientCollateral() public {
        // Setup deposit
        vm.startPrank(user1);
        uint256 depositAmount = 50000 * 10**6; // 50K USDC
        mockUSDC.approve(address(lendingMarket), depositAmount);
        lendingMarket.deposit(depositAmount);
        vm.stopPrank();
        
        mockChainlinkPrice(80000000); // $0.80
        
        vm.startPrank(user2);
        uint256 borrowAmount = 10000 * 10**6; // 10K USDC
        uint256 collateralAmount = 18000 * 10**18; // 18K MNT (worth $14.4K at $0.80, 144% collateral ratio, insufficient for 150% requirement)
        
        mockMNT.approve(address(lendingMarket), collateralAmount);
        vm.expectRevert("Insufficient collateral");
        lendingMarket.borrow(borrowAmount, collateralAmount);
        vm.stopPrank();
    }
    
    function test_RevertInsufficientLiquidity() public {
        mockChainlinkPrice(80000000); // $0.80
        
        vm.startPrank(user2);
        uint256 borrowAmount = 10000 * 10**6; // 10K USDC
        uint256 collateralAmount = 15000 * 10**18; // 15K MNT
        
        mockMNT.approve(address(lendingMarket), collateralAmount);
        vm.expectRevert("Insufficient liquidity");
        lendingMarket.borrow(borrowAmount, collateralAmount);
        vm.stopPrank();
    }
}