export const LENDING_MARKET_ADDRESS = process.env.NEXT_PUBLIC_LENDING_MARKET_ADDRESS;
export const RATE_ADJUSTER_ADDRESS = process.env.NEXT_PUBLIC_RATE_ADJUSTER_ADDRESS;
export const CREDIT_SCORE_ADDRESS = process.env.NEXT_PUBLIC_CREDIT_SCORE_ADDRESS; 
export const USDC_ADDRESS = process.env.NEXT_PUBLIC_USDC_ADDRESS;
export const MNT_ADDRESS = process.env.NEXT_PUBLIC_MNT_ADDRESS;

export const lendingMarketAbi = [
  'function lenderBalances(address) view returns (uint256)',
  'function loans(address) view returns (uint256, uint256, uint256, uint256, uint256)',
  'function deposit(uint256 amount) external',
  'function borrow(uint256 amount, uint256 collateral) external',
  'function repay(uint256 amount) external'
] as const;

export const rateAdjusterAbi = [
  'function getUserRate(address) view returns (uint256)',
  'function updateUserRate(address user, uint256 newRate) external'
] as const;

export const creditScoreAbi = [
  'function getCreditScore(address) view returns (uint256)'
] as const;

export const erc20Abi = [
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function balanceOf(address account) view returns (uint256)'
] as const;
