// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CreditScore.sol";
import "../src/RateAdjuster.sol";
import "../src/LendingMarket.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Mock USDC and MNT addresses (replace with actual testnet addresses)
        address mockUSDC = address(0xYourMockUSDCAddress); // Deploy mock ERC20 if needed
        address mockMNT = address(0xYourMockMNTAddress);   // Deploy mock ERC20 if needed

        // Deploy CreditScore
        CreditScore creditScore = new CreditScore();
        console.log("CreditScore deployed at:", address(creditScore));

        // Deploy RateAdjuster
        RateAdjuster rateAdjuster = new RateAdjuster(address(creditScore));
        console.log("RateAdjuster deployed at:", address(rateAdjuster));

        // Deploy LendingMarket
        LendingMarket lendingMarket = new LendingMarket(mockUSDC, mockMNT, address(rateAdjuster));
        console.log("LendingMarket deployed at:", address(lendingMarket));

        vm.stopBroadcast();
    }
}