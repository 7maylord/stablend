import { ethers, Contract, Wallet, JsonRpcProvider } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

// Mantle testnet provider and wallet
const provider: JsonRpcProvider = new ethers.JsonRpcProvider(process.env.MANTLE_TESTNET_RPC);
const wallet: Wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// CreditScore contract ABI
const creditScoreAbi: string[] = [
  "function updateCreditScore(address user, uint256 transactionCount) external",
  "function getCreditScore(address user) view returns (uint256)"
];

// Contract address (set after deployment via Deploy.s.sol)
const CREDIT_SCORE_ADDRESS: string = "0xYourCreditScoreAddress";

const creditScore: Contract = new ethers.Contract(CREDIT_SCORE_ADDRESS, creditScoreAbi, wallet);

// Mock function to fetch user transaction count
async function getTransactionCount(user: string): Promise<number> {
  // For MVP, use random count; in production, query Mantle RPC
  return Math.floor(Math.random() * 100); // Mock 0-100 transactions
}

// Main function to update credit score for a user
async function updateCreditScores(userAddress: string): Promise<void> {
  try {
    console.log(`Updating credit score for user: ${userAddress}`);

    // Fetch mock transaction count
    const transactionCount: number = await getTransactionCount(userAddress);

    // Call updateCreditScore on CreditScore.sol
    const tx = await creditScore.updateCreditScore(userAddress, transactionCount);
    await tx.wait();

    console.log(`Updated credit score for ${userAddress} with ${transactionCount} transactions`);

    // Verify update
    const updatedScore: bigint = await creditScore.getCreditScore(userAddress);
    console.log(`Verified credit score: ${updatedScore}`);
  } catch (error) {
    console.error("Error updating credit score:", error);
  }
}

// Example usage
const sampleUser: string = "0xSampleUserAddress";
updateCreditScores(sampleUser).catch(console.error);

