import lendingMarketAbi from '../abi/LendingMarketAbi.json';
import rateAdjusterAbi from '../abi/RateAdjuster.json';
import creditScoreAbi from '../abi/CreditScoreAbi.json';
import erc20Abi from '../abi/ERC20Abi.json';

// Contract addresses
export const LENDING_MARKET_ADDRESS = '0xABc85233e3c1475c8B0943A13A5DB7b1f77ED6a7';
export const RATE_ADJUSTER_ADDRESS = '0xb5497CB80F237435797e6B7Be4245b5Dae25703e';
export const CREDIT_SCORE_ADDRESS = '0xda4B11A190A8B30e367080651e905c0B5D3Ab8C6';
export const USDC_ADDRESS = '0x72adE6a1780220074Fd19870210706AbCb7589BF';
export const MNT_ADDRESS = '0x46415f21F1cCd97dfBecccD5dad3948daB8674A2';
export const CHAINLINK_MNT_USD_FEED = '0x4c8962833Db7206fd45671e9DC806e4FcC0dCB78';

// Export ABIs
export { lendingMarketAbi, rateAdjusterAbi, creditScoreAbi, erc20Abi };

// Utility functions for contract interaction
export const formatUnits = (value: bigint, decimals: number): string => {
  return (Number(value) / Math.pow(10, decimals)).toFixed(6);
};

export const parseUnits = (value: string, decimals: number): bigint => {
  return BigInt(Math.floor(Number(value) * Math.pow(10, decimals)));
};

// Contract interaction types
export interface LoanData {
  amount: string;
  collateral: string;
  interest: string;
  rate: string;
}

export interface UserStats {
  balance: string;
  creditScore: string;
  rate: string;
  mntPrice: string;
  utilization: string;
} 