import { ethers, Contract, Wallet, JsonRpcProvider } from "ethers";
import * as dotenv from "dotenv";
import { execSync } from "child_process";
import * as path from "path";

dotenv.config();

// Mantle Sepolia testnet provider and wallet
const provider: JsonRpcProvider = new ethers.JsonRpcProvider(process.env.MANTLE_SEPOLIA_RPC);
const wallet: Wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// RateAdjuster contract ABI
const rateAdjusterAbi: string[] = [
  "function updateUserRate(address user, uint256 newRate) external",
  "function getUserRate(address user) view returns (uint256)"
];

// Contract addresses
const RATE_ADJUSTER_ADDRESS: string = process.env.RATE_ADJUSTER_ADDRESS!;

// Mock Chainlink Functions with admin wallet
async function callChainlinkFunctions(user: string, rate: number): Promise<void> {
  try {
    const rateAdjuster: Contract = new ethers.Contract(RATE_ADJUSTER_ADDRESS, rateAdjusterAbi, wallet);
    const tx = await rateAdjuster.updateUserRate(user, rate);
    await tx.wait();
    console.log(`Mock Chainlink Functions: Updated rate for ${user} to ${rate} basis points`);
  } catch (error) {
    console.error("Error calling Chainlink Functions:", error);
    throw error;
  }
}

// Get AI-predicted rate using virtual environment
async function getAIPredictedRate(user: string): Promise<number> {
  try {
    // Call fetchMarketData.ts
    const data = execSync(`ts-node scripts/fetchMarketData.ts ${user}`, { encoding: "utf-8" });
    const marketData = JSON.parse(data);
    
    // Get the path to the AI directory
    const aiDir = path.join(__dirname, '../off-chain/ai');
    
    // Run rateModel.py with virtual environment
    const rate = execSync(`cd ${aiDir} && ./run_model.sh '${JSON.stringify(marketData)}'`, { encoding: "utf-8" });
    return parseInt(rate);
  } catch (error) {
    console.error("Error getting AI rate:", error);
    return 500; // Fallback 5% rate
  }
}

// Main function
async function updateRates(userAddress: string): Promise<void> {
  try {
    console.log(`Updating rate for user: ${userAddress}`);
    
    // Get AI-predicted rate
    const newRate: number = await getAIPredictedRate(userAddress);
    
    // Call Chainlink Functions (mocked)
    await callChainlinkFunctions(userAddress, newRate);
    
    // Verify update
    const rateAdjuster: Contract = new ethers.Contract(RATE_ADJUSTER_ADDRESS, rateAdjusterAbi, provider);
    const updatedRate: bigint = await rateAdjuster.getUserRate(userAddress);
    console.log(`Verified rate: ${updatedRate} basis points`);
  } catch (error) {
    console.error("Error updating rate:", error);
  }
}

// Example usage
if (require.main === module) {
  const userAddress = process.argv[2] || wallet.address;
  updateRates(userAddress).catch(console.error);
}
