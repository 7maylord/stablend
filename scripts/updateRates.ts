import { ethers, Contract, Wallet, JsonRpcProvider } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

// Mantle testnet provider and wallet
const provider: JsonRpcProvider = new ethers.JsonRpcProvider(process.env.MANTLE_TESTNET_RPC);
const wallet: Wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// RateAdjuster contract ABI
const rateAdjusterAbi: string[] = [
  "function updateUserRate(address user, uint256 newRate) external",
  "function getUserRate(address user) view returns (uint256)"
];

// CreditScore contract ABI
const creditScoreAbi: string[] = [
  "function getCreditScore(address user) view returns (uint256)"
];

// Contract addresses (set after deployment via Deploy.s.sol)
const RATE_ADJUSTER_ADDRESS: string = "0xYourRateAdjusterAddress";
const CREDIT_SCORE_ADDRESS: string = "0xYourCreditScoreAddress";

const rateAdjuster: Contract = new ethers.Contract(RATE_ADJUSTER_ADDRESS, rateAdjusterAbi, wallet);
const creditScore: Contract = new ethers.Contract(CREDIT_SCORE_ADDRESS, creditScoreAbi, wallet);

// Mock AI model: Generates rate based on market data and credit score
async function generateMockRate(user: string): Promise<number> {
  // Mock market data (pool utilization 0-100%)
  const poolUtilization: number = Math.floor(Math.random() * 100);
  const baseRate: number = 500; // 5% in basis points

  // Fetch user's credit score
  const creditScore: bigint = await creditScore.getCreditScore(user);

  // Simplified AI logic: Adjust rate based on utilization and score
  let rateAdjustment: number = poolUtilization * 10; // Higher utilization = higher rate
  rateAdjustment = Math.min(rateAdjustment, 2000); // Cap adjustment at 20%
  const userRate: number = baseRate + (rateAdjustment * (1000 - Number(creditScore))) / 1000;

  return Math.floor(userRate);
}

// Main function to update rates for a user
async function updateRates(userAddress: string): Promise<void> {
  try {
    console.log(`Updating rate for user: ${userAddress}`);

    // Generate mock rate
    const newRate: number = await generateMockRate(userAddress);

    // Call updateUserRate on RateAdjuster.sol
    const tx = await rateAdjuster.updateUserRate(userAddress, newRate);
    await tx.wait();

    console.log(`Updated rate for ${userAddress} to ${newRate} basis points`);

    // Verify update
    const updatedRate: bigint = await rateAdjuster.getUserRate(userAddress);
    console.log(`Verified rate: ${updatedRate} basis points`);
  } catch (error) {
    console.error("Error updating rate:", error);
  }
}

// Example usage
const sampleUser: string = "0xSampleUserAddress";
updateRates(sampleUser).catch(console.error);
