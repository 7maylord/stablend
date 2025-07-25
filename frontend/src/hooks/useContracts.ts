'use client';

import { useState, useEffect } from 'react';
import { useAccount, usePublicClient, useWalletClient } from 'wagmi';
import { createPublicClient, http } from 'viem';
import { 
  LENDING_MARKET_ADDRESS, 
  RATE_ADJUSTER_ADDRESS, 
  CREDIT_SCORE_ADDRESS, 
  USDC_ADDRESS, 
  MNT_ADDRESS,
  CHAINLINK_MNT_USD_FEED,
  lendingMarketAbi, 
  rateAdjusterAbi, 
  creditScoreAbi, 
  erc20Abi,
  formatUnits,
  parseUnits,
  type LoanData,
  type UserStats
} from '@/config/contracts';
import { showSuccessToast, showErrorToast, showInfoToast } from '@/components/ToastContainer';

export function useContracts() {
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();

  // Direct RPC client for Mantle Sepolia
  const mantleRpcUrl = process.env.NEXT_PUBLIC_MANTLE_SEPOLIA_RPC || 'https://mantle-sepolia.g.alchemy.com/v2/hOFsEmyHlw0Ez4aLryoLetL-YwfWJC2D'
  const directPublicClient = createPublicClient({
    chain: {
      id: 5003,
      name: 'Mantle Sepolia',
      network: 'mantle-sepolia',
      nativeCurrency: {
        decimals: 18,
        name: 'Ether',
        symbol: 'ETH',
      },
      rpcUrls: {
        default: { http: [mantleRpcUrl] },
        public: { http: [mantleRpcUrl] },
      },
    },
    transport: http(mantleRpcUrl)
  })

  // State for form inputs
  const [depositAmount, setDepositAmount] = useState('');
  const [borrowAmount, setBorrowAmount] = useState('');
  const [collateralAmount, setCollateralAmount] = useState('');
  const [repayAmount, setRepayAmount] = useState('');

  // State for user data
  const [userStats, setUserStats] = useState<UserStats>({
    balance: '0',
    creditScore: '0',
    rate: '0',
    mntPrice: '0'
  });

  const [loan, setLoan] = useState<LoanData>({
    amount: '0',
    collateral: '0',
    interest: '0',
    rate: '0'
  });

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Fetch user data from contracts
  const fetchUserData = async () => {
    if (!address) return;

    try {
      setIsLoading(true);
      setError(null);

      // Fetch lender balance
      const balance = await directPublicClient.readContract({
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'lenderBalances',
        args: [address]
      });

      // Fetch loan data
      const loanData = await directPublicClient.readContract({
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'loans',
        args: [address]
      });

      // Fetch credit score
      const creditScore = await directPublicClient.readContract({
        address: CREDIT_SCORE_ADDRESS as `0x${string}`,
        abi: creditScoreAbi,
        functionName: 'getCreditScore',
        args: [address]
      });

      // Fetch user rate
      const userRate = await directPublicClient.readContract({
        address: RATE_ADJUSTER_ADDRESS as `0x${string}`,
        abi: rateAdjusterAbi,
        functionName: 'getUserRate',
        args: [address]
      });

      // Fetch MNT price from Chainlink
      const priceData = await directPublicClient.readContract({
        address: CHAINLINK_MNT_USD_FEED as `0x${string}`,
        abi: [
          {
            name: 'latestRoundData',
            type: 'function',
            stateMutability: 'view',
            inputs: [],
            outputs: [
              { name: 'roundId', type: 'uint80' },
              { name: 'answer', type: 'int256' },
              { name: 'startedAt', type: 'uint256' },
              { name: 'updatedAt', type: 'uint256' },
              { name: 'answeredInRound', type: 'uint80' }
            ]
          }
        ],
        functionName: 'latestRoundData',
        args: []
      });

      // Update state
      setUserStats({
        balance: formatUnits(balance as bigint, 6),
        creditScore: (creditScore as bigint).toString(),
        rate: ((userRate as bigint) / BigInt(100)).toString(),
        mntPrice: formatUnits((priceData as any)[1] as bigint, 8)
      });

      setLoan({
        amount: formatUnits((loanData as any)[0] as bigint, 6),
        collateral: formatUnits((loanData as any)[1] as bigint, 18),
        interest: formatUnits((loanData as any)[2] as bigint, 6),
        rate: (loanData as any)[4].toString()
      });

    } catch (err) {
      console.error('Error fetching user data:', err);
      setError('Failed to fetch user data');
    } finally {
      setIsLoading(false);
    }
  };

  // Deposit USDC
  const handleDeposit = async () => {
    if (!address || !walletClient || !publicClient || !depositAmount) return;

    try {
      setIsLoading(true);
      setError(null);

      const amount = parseUnits(depositAmount, 6);

      // First approve USDC spending
      const approveHash = await walletClient.writeContract({
        address: USDC_ADDRESS as `0x${string}`,
        abi: erc20Abi,
        functionName: 'approve',
        args: [LENDING_MARKET_ADDRESS, amount]
      });

      await directPublicClient.waitForTransactionReceipt({ hash: approveHash });

      // Then deposit
      const depositHash = await walletClient.writeContract({
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'deposit',
        args: [amount]
      });

      await directPublicClient.waitForTransactionReceipt({ hash: depositHash });

      // Refresh data
      await fetchUserData();
      setDepositAmount('');
      showSuccessToast('Deposit successful! 🎉');

    } catch (err) {
      console.error('Deposit error:', err);
      const errorMessage = err instanceof Error ? err.message : 'Deposit failed';
      setError('Deposit failed');
      
      if (errorMessage.includes('gas')) {
        showErrorToast('Transaction failed: Gas limit too low. Please try again.');
      } else if (errorMessage.includes('insufficient')) {
        showErrorToast('Insufficient USDC balance. Please check your balance.');
      } else {
        showErrorToast('Deposit failed. Please try again.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  // Borrow USDC
  const handleBorrow = async () => {
    if (!address || !walletClient || !publicClient || !borrowAmount || !collateralAmount) return;

    try {
      setIsLoading(true);
      setError(null);

      const borrowAmountParsed = parseUnits(borrowAmount, 6);
      const collateralAmountParsed = parseUnits(collateralAmount, 18);

      // Approve MNT spending
      const approveHash = await walletClient.writeContract({
        address: MNT_ADDRESS as `0x${string}`,
        abi: erc20Abi,
        functionName: 'approve',
        args: [LENDING_MARKET_ADDRESS, collateralAmountParsed]
      });

      await directPublicClient.waitForTransactionReceipt({ hash: approveHash });

      // Borrow
      const borrowHash = await walletClient.writeContract({
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'borrow',
        args: [borrowAmountParsed, collateralAmountParsed]
      });

      await directPublicClient.waitForTransactionReceipt({ hash: borrowHash });

      // Refresh data
      await fetchUserData();
      setBorrowAmount('');
      setCollateralAmount('');
      showSuccessToast('Borrow successful! 💰');

    } catch (err) {
      console.error('Borrow error:', err);
      const errorMessage = err instanceof Error ? err.message : 'Borrow failed';
      setError('Borrow failed');
      
      if (errorMessage.includes('gas')) {
        showErrorToast('Transaction failed: Gas limit too low. Please try again.');
      } else if (errorMessage.includes('Insufficient collateral')) {
        showErrorToast('Insufficient collateral. Please increase your MNT amount.');
      } else if (errorMessage.includes('Insufficient liquidity')) {
        showErrorToast('Insufficient liquidity in the protocol. Please try a smaller amount.');
      } else {
        showErrorToast('Borrow failed. Please check your collateral and try again.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  // Repay loan
  const handleRepay = async () => {
    if (!address || !walletClient || !publicClient || !repayAmount) return;

    try {
      setIsLoading(true);
      setError(null);

      const amount = parseUnits(repayAmount, 6);

      // Get current loan data to calculate total debt
      const loanData = await directPublicClient.readContract({
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'loans',
        args: [address]
      });

      const totalDebt = ((loanData as any)[0] as bigint) + ((loanData as any)[2] as bigint);

      // Approve USDC spending for total debt
      const approveHash = await walletClient.writeContract({
        address: USDC_ADDRESS as `0x${string}`,
        abi: erc20Abi,
        functionName: 'approve',
        args: [LENDING_MARKET_ADDRESS, totalDebt]
      });

      await directPublicClient.waitForTransactionReceipt({ hash: approveHash });

      // Repay
      const repayHash = await walletClient.writeContract({
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'repay',
        args: [amount]
      });

      await directPublicClient.waitForTransactionReceipt({ hash: repayHash });

      // Refresh data
      await fetchUserData();
      setRepayAmount('');
      showSuccessToast('Repayment successful! ✅');

    } catch (err) {
      console.error('Repay error:', err);
      const errorMessage = err instanceof Error ? err.message : 'Repay failed';
      setError('Repay failed');
      
      if (errorMessage.includes('gas')) {
        showErrorToast('Transaction failed: Gas limit too low. Please try again.');
      } else if (errorMessage.includes('insufficient')) {
        showErrorToast('Insufficient USDC balance. Please check your balance.');
      } else {
        showErrorToast('Repayment failed. Please try again.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  // Fetch data when user connects
  useEffect(() => {
    if (isConnected && address) {
      fetchUserData();
    }
  }, [isConnected, address]);

  return {
    // State
    depositAmount,
    setDepositAmount,
    borrowAmount,
    setBorrowAmount,
    collateralAmount,
    setCollateralAmount,
    repayAmount,
    setRepayAmount,
    userStats,
    loan,
    isLoading,
    error,

    // Actions
    handleDeposit,
    handleBorrow,
    handleRepay,
    fetchUserData
  };
} 