// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockMNT.sol";
import "../src/CreditScore.sol";
import "../src/RateAdjuster.sol";
import "../src/LendingMarket.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock tokens
        MockUSDC mockUSDC = new MockUSDC();
        console.log("MockUSDC deployed at:", address(mockUSDC));
        
        MockMNT mockMNT = new MockMNT();
        console.log("MockMNT deployed at:", address(mockMNT));
        
        // Deploy CreditScore contract
        CreditScore creditScore = new CreditScore();
        console.log("CreditScore deployed at:", address(creditScore));
        
        // Deploy RateAdjuster contract
        RateAdjuster rateAdjuster = new RateAdjuster(
            address(creditScore),
            deployer // Mock Chainlink Functions address
        );
        console.log("RateAdjuster deployed at:", address(rateAdjuster));
        
        // Get Chainlink feed address from environment or use default
        address chainlinkFeed = vm.envOr("CHAINLINK_MNT_USD_FEED", address(0x4c8962833Db7206fd45671e9DC806e4FcC0dCB78));
        
        // Deploy LendingMarket contract
        LendingMarket lendingMarket = new LendingMarket(
            address(mockUSDC),
            address(mockMNT),
            address(rateAdjuster),
            chainlinkFeed
        );
        console.log("LendingMarket deployed at:", address(lendingMarket));
        
        // Mint some initial tokens for testing
        mockUSDC.mint(deployer, 1000000 * 10**6); // 1M USDC
        mockMNT.mint(deployer, 1000000 * 10**18); // 1M MNT
        
        vm.stopBroadcast();
        
        // Output deployment addresses for .env file
        console.log("\n=== DEPLOYMENT ADDRESSES ===");
        console.log("MOCK_USDC_ADDRESS=", address(mockUSDC));
        console.log("MOCK_MNT_ADDRESS=", address(mockMNT));
        console.log("CREDIT_SCORE_ADDRESS=", address(creditScore));
        console.log("RATE_ADJUSTER_ADDRESS=", address(rateAdjuster));
        console.log("LENDING_MARKET_ADDRESS=", address(lendingMarket));
        console.log("CHAINLINK_MNT_USD_FEED=", chainlinkFeed);
        
        console.log("\n=== INITIAL TOKENS MINTED ===");
        console.log("Deployer received: 1,000,000 USDC and 1,000,000 MNT");
    }
}