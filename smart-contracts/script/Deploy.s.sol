// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockMNT.sol";
import "../src/mocks/MockChainlinkFeed.sol";
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

        
        address chainlinkFeed = vm.envOr("CHAINLINK_MNT_USD_FEED", address(0));
        
        if (chainlinkFeed == address(0)) {
            // Deploy mock Chainlink feed for local development
            MockChainlinkFeed mockChainlinkFeed = new MockChainlinkFeed();
            chainlinkFeed = address(mockChainlinkFeed);
            console.log("MockChainlinkFeed deployed at:", chainlinkFeed);
        } else {
            console.log("Using real Chainlink feed at:", chainlinkFeed);
        }

        // Deploy CreditScore contract
        CreditScore creditScore = new CreditScore();
        console.log("CreditScore deployed at:", address(creditScore));

        // Deploy RateAdjuster contract
        RateAdjuster rateAdjuster = new RateAdjuster(
            address(creditScore),
            deployer // Mock Chainlink Functions address
        );
        console.log("RateAdjuster deployed at:", address(rateAdjuster));

        // Deploy LendingMarket contract with Chainlink feed
        LendingMarket lendingMarket =
            new LendingMarket(address(mockUSDC), address(mockMNT), address(rateAdjuster), chainlinkFeed);
        console.log("LendingMarket deployed at:", address(lendingMarket));

        // Mint some initial tokens for testing
        mockUSDC.mint(deployer, 1000000 * 10 ** 6); // 1M USDC
        mockMNT.mint(deployer, 1000000 * 10 ** 18); // 1M MNT

        vm.stopBroadcast();

        // Get real balances from on-chain
        uint256 usdcBalance = mockUSDC.balanceOf(deployer);
        uint256 mntBalance = mockMNT.balanceOf(deployer);
        uint256 ethBalance = deployer.balance;

        // Output deployment addresses for .env file
        console.log("\n=== DEPLOYMENT ADDRESSES ===");
        console.log("MOCK_USDC_ADDRESS=", address(mockUSDC));
        console.log("MOCK_MNT_ADDRESS=", address(mockMNT));
        console.log("CHAINLINK_MNT_USD_FEED=", chainlinkFeed);
        console.log("CREDIT_SCORE_ADDRESS=", address(creditScore));
        console.log("RATE_ADJUSTER_ADDRESS=", address(rateAdjuster));
        console.log("LENDING_MARKET_ADDRESS=", address(lendingMarket));

        console.log("\n=== REAL BALANCES ===");
        console.log("Deployer USDC balance:", usdcBalance / 10**6, "USDC");
        console.log("Deployer MNT balance:", mntBalance / 10**18, "MNT");
        console.log("Deployer ETH balance:", ethBalance / 10**18, "ETH");
        // Get real MNT price from Chainlink if available
        if (chainlinkFeed != address(0)) {
            try AggregatorV3Interface(chainlinkFeed).latestRoundData() returns (uint80, int256 price, uint256, uint256, uint80) {
                uint8 decimals = AggregatorV3Interface(chainlinkFeed).decimals();
                uint256 priceInUSD = uint256(price) / (10 ** decimals);
                console.log("Real MNT price from Chainlink:", priceInUSD, "USD");
            } catch {
                console.log("Could not fetch real MNT price from Chainlink");
            }
        } else {
            console.log("Mock MNT price set to: $0.80");
        }
    }
}
