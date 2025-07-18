import { ethers, Contract, JsonRpcProvider } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

const provider: JsonRpcProvider = new ethers.JsonRpcProvider(process.env.MANTLE_SEPOLIA_RPC);
const lendingMarketAbi: string[] = [
  "function lenderBalances(address) view returns (uint256)",
  "function loans(address) view returns (uint256, uint256, uint256, uint256, uint256)",
  "function totalDeposits() view returns (uint256)",
  "function totalBorrows() view returns (uint256)"
];
const creditScoreAbi: string[] = ["function getCreditScore(address) view returns (uint256)"];
const chainlinkAbi: string[] = ["function latestRoundData() view returns (uint80, int256, uint256, uint256, uint80)"];
const lendingMarket: Contract = new ethers.Contract(process.env.LENDING_MARKET_ADDRESS!, lendingMarketAbi, provider);
const creditScoreContract: Contract = new ethers.Contract(process.env.CREDIT_SCORE_ADDRESS!, creditScoreAbi, provider);
// Mantle Sepolia Chainlink MNT/USD feed
const chainlinkFeed: Contract = new ethers.Contract(process.env.CHAINLINK_MNT_USD_FEED!, chainlinkAbi, provider);

async function fetchMarketData(user: string): Promise<any> {
  try {
    // Calculate pool utilization using total values
    const totalDeposits: bigint = await lendingMarket.totalDeposits();
    const totalBorrows: bigint = await lendingMarket.totalBorrows();
    const utilization: number = totalDeposits > 0 ? Number((totalBorrows * BigInt(100)) / totalDeposits) : 0;
    
    // Get credit score
    const userCreditScore: bigint = await creditScoreContract.getCreditScore(user);
    
    // Get MNT price from Chainlink MNT/USD feed
    const [, price,,,] = await chainlinkFeed.latestRoundData();
    if (price <= 0) throw new Error("Invalid Chainlink price");
    const mntPrice: number = Number(price) / 1e8; // Chainlink price in 8 decimals
    
    return { utilization, credit_score: Number(userCreditScore), mnt_price: mntPrice };
  } catch (error) {
    console.error("Error fetching market data:", error);
    throw error;
  }
}

// Example usage
if (require.main === module) {
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
  const userAddress = process.argv[2] || wallet.address;
  fetchMarketData(userAddress).then(data => console.log(JSON.stringify(data))).catch(console.error);
}
