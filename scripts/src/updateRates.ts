import { ethers, Contract, Wallet, JsonRpcProvider } from "ethers";
import * as dotenv from "dotenv";
import { fetchMarketData } from "./fetchMarketData";

// Import RateAdjuster ABI and type definitions
import RateAdjusterABI from '../abi/RateAdjuster.json';

dotenv.config();

// Types for API response
interface AIApiResponse {
  success: boolean;
  rate: number;
  error?: string;
}

// Mantle Sepolia testnet provider and wallet
const provider: JsonRpcProvider = new ethers.JsonRpcProvider(process.env.MANTLE_SEPOLIA_RPC);
const wallet: Wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// Contract addresses
const RATE_ADJUSTER_ADDRESS: string = process.env.RATE_ADJUSTER_ADDRESS!;

// AI API endpoint (production)
const AI_API_ENDPOINT: string = process.env.AI_API_ENDPOINT || 'https://stablend.onrender.com/predict';


// Mock Chainlink Functions with admin wallet
async function callChainlinkFunctions(user: string, rate: number): Promise<void> {
  try {
    const rateAdjuster: Contract = new ethers.Contract(RATE_ADJUSTER_ADDRESS, RateAdjusterABI, wallet);
    const tx = await rateAdjuster.updateUserRate(user, rate);
    await tx.wait();
    console.log(`Mock Chainlink Functions: Updated rate for ${user} to ${rate} basis points`);
  } catch (error) {
    console.error("Error calling Chainlink Functions:", error);
    throw error;
  }
}

// Get AI-predicted rate from production API
async function getAIPredictedRate(user: string): Promise<number> {
  try {
    // Get market data directly
    const marketData = await fetchMarketData(user);
    
    // Call production AI API
    const response = await fetch(AI_API_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(marketData),
    });

    if (!response.ok) {
      throw new Error(`AI API responded with status: ${response.status}`);
    }

    const result = await response.json() as AIApiResponse;
    
    if (!result.success) {
      throw new Error(`AI API error: ${result.error}`);
    }

    const rate = result.rate;
    
    // Validate the rate is a valid number
    if (isNaN(rate) || rate <= 0) {
      console.log("AI model returned invalid rate, using fallback");
      return 500; // Fallback 5% rate
    }
    
    return rate;
  } catch (error) {
    console.error("Error getting AI rate:", error);
    console.log("Using fallback rate of 500 basis points (5%)");
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
    const rateAdjuster: Contract = new ethers.Contract(RATE_ADJUSTER_ADDRESS, RateAdjusterABI, provider);
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
