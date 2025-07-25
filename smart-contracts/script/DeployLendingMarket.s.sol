// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LendingMarket.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockMNT.sol";
import "../src/CreditScore.sol";
import "../src/RateAdjuster.sol";

contract DeployLendingMarketScript is Script {
    // Existing deployed contract addresses from Mantle Sepolia
    address constant MOCK_USDC_ADDRESS = 0x72adE6a1780220074Fd19870210706AbCb7589BF;
    address constant MOCK_MNT_ADDRESS = 0x46415f21F1cCd97dfBecccD5dad3948daB8674A2;
    address constant CREDIT_SCORE_ADDRESS = 0xda4B11A190A8B30e367080651e905c0B5D3Ab8C6;
    address constant RATE_ADJUSTER_ADDRESS = 0xb5497CB80F237435797e6B7Be4245b5Dae25703e;
    address constant CHAINLINK_MNT_USD_FEED = 0x4c8962833Db7206fd45671e9DC806e4FcC0dCB78;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deploying LendingMarket with arithmetic overflow fixes...");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the new LendingMarket contract
        LendingMarket lendingMarket = new LendingMarket(
            MOCK_USDC_ADDRESS,    // USDC token address
            MOCK_MNT_ADDRESS,     // MNT token address  
            RATE_ADJUSTER_ADDRESS, // Rate adjuster address
            CHAINLINK_MNT_USD_FEED // Chainlink price feed address
        );

        vm.stopBroadcast();

        console.log("=== LENDING MARKET REDEPLOYMENT SUCCESSFUL ===");
        console.log("New LendingMarket address:", address(lendingMarket));
        console.log("Network: Mantle Sepolia (Chain ID: 5003)");
        console.log("");
        console.log("=== CONTRACT ADDRESSES ===");
        console.log("MockUSDC:", MOCK_USDC_ADDRESS);
        console.log("MockMNT:", MOCK_MNT_ADDRESS);
        console.log("CreditScore:", CREDIT_SCORE_ADDRESS);
        console.log("RateAdjuster:", RATE_ADJUSTER_ADDRESS);
        console.log("Chainlink MNT/USD Feed:", CHAINLINK_MNT_USD_FEED);
        console.log("LendingMarket (NEW):", address(lendingMarket));
        console.log("");
        console.log("=== FRONTEND CONFIG UPDATE ===");
        console.log("Update your frontend config with the new LendingMarket address:");
        console.log("LENDING_MARKET_ADDRESS =", address(lendingMarket));
        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("The new LendingMarket contract has been deployed with arithmetic overflow fixes.");
        console.log("The borrow function should now work without gas estimation errors.");
    }
} 