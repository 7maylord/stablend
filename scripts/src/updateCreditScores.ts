import { ethers, Contract, Wallet, JsonRpcProvider } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

// Mantle testnet provider and wallet
const provider: JsonRpcProvider = new ethers.JsonRpcProvider(process.env.MANTLE_TESTNET_RPC);
const wallet: Wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// CreditScore and LendingMarket contract ABIs
const creditScoreAbi: string[] = [
  "function updateCreditScore(address user, uint256 transactionCount) external",
  "function getCreditScore(address user) view returns (uint256)"
];
const lendingMarketAbi: string[] = [
  "event Repay(address indexed user, uint256 amount)"
];

// Contract addresses
const CREDIT_SCORE_ADDRESS: string = process.env.CREDIT_SCORE_ADDRESS!;
const LENDING_MARKET_ADDRESS: string = process.env.LENDING_MARKET_ADDRESS!;

const creditScore: Contract = new ethers.Contract(CREDIT_SCORE_ADDRESS, creditScoreAbi, wallet);
const lendingMarket: Contract = new ethers.Contract(LENDING_MARKET_ADDRESS, lendingMarketAbi, provider);

// Fetch transaction count and repayment data
async function getTransactionCount(user: string): Promise<number> {
  try {
    // Get transaction count from Mantle RPC
    const txCount: number = await provider.getTransactionCount(user);
    
    // Count repayment events from LendingMarket.sol (with error handling)
    let repayCount: number = 0;
    try {
      const filter = lendingMarket.filters.Repay(user);
      // Query last 1000 blocks instead of from very old block
      const latestBlock = await provider.getBlockNumber();
      const fromBlock = Math.max(0, latestBlock - 1000);
      const events = await lendingMarket.queryFilter(filter, fromBlock, latestBlock);
      repayCount = events.length;
    } catch (eventError) {
      console.log("No Repay events found or RPC error (this is normal for new contracts)");
      repayCount = 0;
    }
    
    // Combine for score (max 100)
    return Math.min(txCount + repayCount * 10, 100);
  } catch (error) {
    console.error("Error fetching transaction count:", error);
    return 0;
  }
}

// Main function to update credit score
async function updateCreditScores(userAddress: string): Promise<void> {
  try {
    console.log(`Updating credit score for user: ${userAddress}`);
    
    // Fetch transaction count
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
if (require.main === module) {
  const userAddress = process.argv[2] || wallet.address;
  updateCreditScores(userAddress).catch(console.error);
}