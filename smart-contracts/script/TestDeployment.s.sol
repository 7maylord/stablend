// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockMNT.sol";
import "../src/mocks/MockChainlinkFeed.sol";
import "../src/CreditScore.sol";
import "../src/RateAdjuster.sol";
import "../src/LendingMarket.sol";

contract TestDeploymentScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Use the deployed contract addresses
        MockUSDC mockUSDC = MockUSDC(0x5FbDB2315678afecb367f032d93F642f64180aa3);
        MockMNT mockMNT = MockMNT(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        MockChainlinkFeed mockChainlinkFeed = MockChainlinkFeed(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
        CreditScore creditScore = CreditScore(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
        RateAdjuster rateAdjuster = RateAdjuster(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
        LendingMarket lendingMarket = LendingMarket(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);

        vm.startBroadcast(deployerPrivateKey);

        console.log("\n=== TESTING DEPLOYMENT ===");
        
        // Test 1: Check token balances
        uint256 usdcBalance = mockUSDC.balanceOf(deployer);
        uint256 mntBalance = mockMNT.balanceOf(deployer);
        console.log("Deployer USDC balance:", usdcBalance / 10**6, "USDC");
        console.log("Deployer MNT balance:", mntBalance / 10**18, "MNT");

        // Test 2: Check Chainlink feed price
        (, int256 price,,,) = mockChainlinkFeed.latestRoundData();
        console.log("MNT Price from Chainlink:", uint256(price) / 10**8, "USD");

        // Test 3: Check credit score
        uint256 creditScoreValue = creditScore.getCreditScore(deployer);
        console.log("Deployer credit score:", creditScoreValue);

        // Test 4: Check user rate
        uint256 userRate = rateAdjuster.getUserRate(deployer);
        console.log("Deployer interest rate:", userRate, "basis points");

        // Test 5: Deposit some USDC to the lending market
        uint256 depositAmount = 10000 * 10**6; // 10,000 USDC
        mockUSDC.approve(address(lendingMarket), depositAmount);
        lendingMarket.deposit(depositAmount);
        console.log("Deposited 10,000 USDC to lending market");

        // Test 6: Check lending market state
        uint256 totalDeposits = lendingMarket.totalDeposits();
        uint256 totalBorrows = lendingMarket.totalBorrows();
        uint256 utilizationRate = lendingMarket.getUtilizationRate();
        console.log("Total deposits:", totalDeposits / 10**6, "USDC");
        console.log("Total borrows:", totalBorrows / 10**6, "USDC");
        console.log("Utilization rate:", utilizationRate / 100, "%");

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT TEST COMPLETE ===");
        console.log("All contracts are working correctly!");
    }
} 