'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { useAccount } from 'wagmi';
import { createPublicClient, createWalletClient, http, custom } from 'viem';
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

  // Direct wallet client using window.ethereum
  const directWalletClient = createWalletClient({
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
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    transport: custom(window.ethereum as any)
  })

  // State for form inputs
  const [depositAmount, setDepositAmount] = useState('');
  const [borrowAmount, setBorrowAmount] = useState('');
  const [collateralAmount, setCollateralAmount] = useState('');
  const [repayAmount, setRepayAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');

  // State for user data
  const [userStats, setUserStats] = useState<UserStats>({
    balance: '0',
    creditScore: '0',
    rate: '0',
    mntPrice: '0',
    utilization: '0'
  });

  const [loan, setLoan] = useState<LoanData>({
    amount: '0',
    collateral: '0',
    interest: '0',
    rate: '0'
  });

  const [isLoading, setIsLoading] = useState(false);
  const isFetchingRef = useRef(false);
  const hasInitialFetchRef = useRef(false);

  // Helper function to calculate required collateral for a given borrow amount
const calculateRequiredCollateral = (borrowAmountUsdc: string): string => {
  if (!borrowAmountUsdc || Number(borrowAmountUsdc) <= 0 || Number(userStats.mntPrice) <= 0) {
    return '0';
  }

  try {
    // Parse inputs
    const borrowAmountParsed = parseUnits(borrowAmountUsdc, 6); // USDC has 6 decimals
    const mntPriceUsd = parseUnits(userStats.mntPrice, 8); // Chainlink price has 8 decimals
    
    // Scale borrow amount to 18 decimals for calculation
    const borrowAmountUsd18 = borrowAmountParsed * BigInt(10 ** 12);
    
    // Apply 150% collateralization ratio
    const requiredCollateralUsd18 = (borrowAmountUsd18 * BigInt(150)) / BigInt(100);
    
    // Convert USD value back to MNT amount
    // requiredCollateralUsd18 (18 decimals) / mntPriceUsd (8 decimals) * 1e8 = MNT amount (18 decimals)
    const requiredMntAmount = (requiredCollateralUsd18 * BigInt(1e8)) / mntPriceUsd;
    
    return formatUnits(requiredMntAmount, 18);
  } catch (error) {
    console.error('Error calculating required collateral:', error);
    return '0';
  }
};

// Helper function to calculate max borrow for a given collateral amount
const calculateMaxBorrow = (collateralAmountMnt: string): string => {
  if (!collateralAmountMnt || Number(collateralAmountMnt) <= 0 || Number(userStats.mntPrice) <= 0) {
    return '0';
  }

  try {
    // Parse inputs
    const mntAmount = parseUnits(collateralAmountMnt, 18); // MNT has 18 decimals
    const mntPriceUsd = parseUnits(userStats.mntPrice, 8); // Chainlink price has 8 decimals
    
    // Calculate collateral value in USD (18 decimals)
    const collateralValueUsd18 = (mntAmount * mntPriceUsd) / BigInt(1e8);
    
    // Apply inverse of 150% ratio (divide by 1.5) to get max borrow
    const maxBorrowUsd18 = (collateralValueUsd18 * BigInt(100)) / BigInt(150);
    
    // Scale back to USDC decimals (6)
    const maxBorrowUsdc = maxBorrowUsd18 / BigInt(10 ** 12);
    
    return formatUnits(maxBorrowUsdc, 6);
  } catch (error) {
    console.error('Error calculating max borrow:', error);
    return '0';
  }
};

// Fixed frontend validation before contract call
const _validateBorrowInputs = (borrowAmount: string, collateralAmount: string): string | null => {
  // Check if user already has an active loan
  if (Number(loan.amount) > 0) {
    return 'You already have an active loan. Please repay your current loan first.';
  }

  // Check if amounts are valid
  if (Number(borrowAmount) <= 0 || Number(collateralAmount) <= 0) {
    return 'Please enter valid amounts greater than 0';
  }

  // Check collateralization ratio
  if (Number(userStats.mntPrice) > 0) {
    try {
      const borrowAmountParsed = parseUnits(borrowAmount, 6);
      const collateralAmountParsed = parseUnits(collateralAmount, 18);
      const mntPriceUsd = parseUnits(userStats.mntPrice, 8);
      
      // Calculate collateral value in USD (18 decimals)
      const collateralValueUsd18 = (collateralAmountParsed * mntPriceUsd) / BigInt(1e8);
      
      // Calculate required collateral (18 decimals)
      const borrowAmountUsd18 = borrowAmountParsed * BigInt(10 ** 12);
      const requiredCollateralUsd18 = (borrowAmountUsd18 * BigInt(150)) / BigInt(100);

      if (collateralValueUsd18 < requiredCollateralUsd18) {
        const requiredMnt = formatUnits((requiredCollateralUsd18 * BigInt(1e8)) / mntPriceUsd, 18);
        return `Insufficient collateral. You need at least ${Number(requiredMnt).toFixed(4)} MNT for this borrow amount.`;
      }
    } catch (error) {
      console.error('Validation error:', error);
      return 'Error validating inputs. Please check your amounts.';
    }
  }

  return null; // No validation errors
};

  // Helper function to estimate gas with buffer
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const estimateGasWithBuffer = async (contractCall: any) => {
    try {
      console.log('Estimating gas for:', contractCall.functionName);
      const gasEstimate = await directPublicClient.estimateContractGas(contractCall);
      console.log('Raw gas estimate:', gasEstimate.toString());
      
      // Add 20% buffer to gas estimate
      const gasWithBuffer = gasEstimate + (gasEstimate * BigInt(20)) / BigInt(100);
      console.log('Gas with 20% buffer:', gasWithBuffer.toString());
      
      return gasWithBuffer;
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    } catch (error) {
      console.error('Gas estimation failed for', contractCall.functionName, ':', error);
      console.log('Using fallback gas limit: 200,000,000');
      return BigInt(200000000); 
    }
  };

  // Fetch user data from contracts
  const fetchUserData = useCallback(async (showToast = false) => {
    if (!address) return;
    
    // Prevent multiple simultaneous calls
    if (isFetchingRef.current) return;
    isFetchingRef.current = true;

    try {
      setIsLoading(true);
      if (showToast) {
        showInfoToast('Refreshing your data... 🔄');
      }

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

      // Fetch market utilization rate
      const utilizationRate = await directPublicClient.readContract({
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'getUtilizationRate',
        args: []
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
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        mntPrice: formatUnits((priceData as any)[1] as bigint, 8),
        utilization: ((utilizationRate as bigint) / BigInt(100)).toString()
      });

      setLoan({
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        amount: formatUnits((loanData as any)[0] as bigint, 6),
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        collateral: formatUnits((loanData as any)[1] as bigint, 18),
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        interest: formatUnits((loanData as any)[2] as bigint, 6),
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        rate: (loanData as any)[4].toString()
      });

    } catch (err) {
      console.error('Error fetching user data:', err);
      showErrorToast('Failed to fetch user data');
    } finally {
      setIsLoading(false);
      isFetchingRef.current = false;
    }
  }, [address, directPublicClient, formatUnits, setUserStats, setLoan, showInfoToast, showErrorToast]);

  // Handle deposit
  const handleDeposit = async () => {
    if (!address || !depositAmount) {
      showErrorToast('Please connect wallet and enter amount');
      return;
    }

    // Frontend validation: Check if amount is valid
    if (Number(depositAmount) <= 0) {
      showErrorToast('Please enter a valid amount greater than 0');
      return;
    }

    try {
      setIsLoading(true);
      showInfoToast('Depositing...');

      const amount = parseUnits(depositAmount, 6);

      // First approve USDC spending
      const approveCall = {
        address: USDC_ADDRESS as `0x${string}`,
        abi: erc20Abi,
        functionName: 'approve',
        args: [LENDING_MARKET_ADDRESS, amount],
        account: address
      };

      const approveGas = await estimateGasWithBuffer(approveCall);
      
      const approveHash = await directWalletClient.writeContract({
        ...approveCall,
        gas: approveGas
      });

      await directPublicClient.waitForTransactionReceipt({ hash: approveHash });

      // Then deposit
      const depositCall = {
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'deposit',
        args: [amount],
        account: address
      };

      const depositGas = await estimateGasWithBuffer(depositCall);

      const depositHash = await directWalletClient.writeContract({
        ...depositCall,
        gas: depositGas
      });

      await directPublicClient.waitForTransactionReceipt({ hash: depositHash });

      // Refresh data
      await fetchUserData(false);
      setDepositAmount('');
      showSuccessToast('Deposit successful!');
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } catch (err: any) {
      console.error('Deposit error:', err);
      let errorMessage = 'Deposit failed';
      
      if (err.message?.includes('insufficient')) {
        errorMessage = 'Insufficient USDC balance';
      } else if (err.message?.includes('gas')) {
        errorMessage = 'Gas estimation failed or insufficient gas';
      } else if (err.message?.includes('rejected')) {
        errorMessage = 'Transaction rejected by user';
      }
      
      showErrorToast(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  // Handle borrow
  const handleBorrow = async () => {
    if (!address || !borrowAmount || !collateralAmount) {
      showErrorToast('Please connect wallet and enter amounts');
      return;
    }

    try {
      setIsLoading(true);
      showInfoToast('Borrowing...');

      const borrowAmountParsed = parseUnits(borrowAmount, 6);
      const collateralAmountParsed = parseUnits(collateralAmount, 18);

      // Console log all input values for debugging
      console.log('=== BORROW TRANSACTION DEBUG ===');
      console.log('User inputs:');
      console.log('- borrowAmount (string):', borrowAmount);
      console.log('- collateralAmount (string):', collateralAmount);
      console.log('- address:', address);
      console.log('Parsed values:');
      console.log('- borrowAmountParsed (bigint):', borrowAmountParsed.toString());
      console.log('- collateralAmountParsed (bigint):', collateralAmountParsed.toString());
      console.log('Current user stats:');
      console.log('- userStats.mntPrice:', userStats.mntPrice);
      console.log('- userStats.balance:', userStats.balance);
      console.log('- loan.amount:', loan.amount);
      console.log('Contract addresses:');
      console.log('- LENDING_MARKET_ADDRESS:', LENDING_MARKET_ADDRESS);
      console.log('- MNT_ADDRESS:', MNT_ADDRESS);
      
      // Calculate what the contract will calculate
      const mntPriceIn8Decimals = BigInt(Math.floor(Number(userStats.mntPrice) * 1e8));
      const collateralValue = (collateralAmountParsed * mntPriceIn8Decimals) / BigInt(1e8);
      const requiredCollateral = ((borrowAmountParsed * BigInt(10 ** 12)) * BigInt(150)) / BigInt(100);
      
      console.log('Contract calculation simulation:');
      console.log('- MNT price in 8 decimals:', mntPriceIn8Decimals.toString());
      console.log('- Collateral value (18 decimals):', collateralValue.toString());
      console.log('- Required collateral (18 decimals):', requiredCollateral.toString());
      console.log('- Collateral sufficient:', collateralValue >= requiredCollateral);
      console.log('================================');

      // Frontend validation: Check if user already has an active loan
      if (Number(loan.amount) > 0) {
        showErrorToast('You already have an active loan. Please repay your current loan first.');
        setIsLoading(false);
        return;
      }

      // Frontend validation: Check if amounts are valid
      if (Number(borrowAmount) <= 0 || Number(collateralAmount) <= 0) {
        showErrorToast('Please enter valid amounts greater than 0');
        setIsLoading(false);
        return;
      }

      // Frontend validation: Check collateralization ratio before calling contract
      if (Number(userStats.mntPrice) > 0) {
        const mntPrice = BigInt(Math.floor(Number(userStats.mntPrice) * 1e8)); // Convert to 8 decimals
        const collateralValue = (collateralAmountParsed * mntPrice) / BigInt(1e8); // 18 decimals
        const requiredCollateral = ((borrowAmountParsed * BigInt(10 ** 12)) * BigInt(150)) / BigInt(100); // 150% ratio, 18 decimals

        if (collateralValue < requiredCollateral) {
          const requiredMnt = formatUnits(requiredCollateral / mntPrice * BigInt(1e8), 18);
          showErrorToast(`Insufficient collateral. You need at least ${requiredMnt} MNT for this borrow amount.`);
          setIsLoading(false);
          return;
        }
      }

      // Approve MNT spending with proper gas estimation
      const approveCall = {
        address: MNT_ADDRESS as `0x${string}`,
        abi: erc20Abi,
        functionName: 'approve',
        args: [LENDING_MARKET_ADDRESS, collateralAmountParsed],
        account: address
      };

      console.log('=== APPROVE TRANSACTION ===');
      console.log('Approve call:', approveCall);
      
      const approveGas = await estimateGasWithBuffer(approveCall);
      console.log('Approved gas estimate:', approveGas.toString());
      
      const approveHash = await directWalletClient.writeContract({
        ...approveCall,
        gas: approveGas
      });
      console.log('Approve transaction hash:', approveHash);

      await directPublicClient.waitForTransactionReceipt({ hash: approveHash });

      // Borrow with proper gas estimation
      const borrowCall = {
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'borrow',
        args: [borrowAmountParsed, collateralAmountParsed],
        account: address
      };

      console.log('=== BORROW TRANSACTION ===');
      console.log('Borrow call:', borrowCall);
      
      const borrowGas = await estimateGasWithBuffer(borrowCall);
      console.log('Borrow gas estimate:', borrowGas.toString());

      const borrowHash = await directWalletClient.writeContract({
        ...borrowCall,
        gas: borrowGas
      });
      console.log('Borrow transaction hash:', borrowHash);

      await directPublicClient.waitForTransactionReceipt({ hash: borrowHash });

      // Refresh data
      await fetchUserData(false);
      setBorrowAmount('');
      setCollateralAmount('');
      showSuccessToast('Borrow successful!');
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } catch (err: any) {
      console.error('=== BORROW ERROR ===');
      console.error('Error object:', err);
      console.error('Error message:', err.message);
      console.error('Error code:', err.code);
      console.error('Error details:', err.details);
      console.error('Error data:', err.data);
      console.error('Error reason:', err.reason);
      console.error('Full error stack:', err.stack);
      console.error('=====================');
      
      let errorMessage = 'Borrow failed';
      
      if (err.message?.includes('insufficient')) {
        errorMessage = 'Insufficient collateral or balance';
      } else if (err.message?.includes('liquidity')) {
        errorMessage = 'Insufficient liquidity';
      } else if (err.message?.includes('gas')) {
        errorMessage = 'Gas estimation failed or insufficient gas';
      } else if (err.message?.includes('rejected')) {
        errorMessage = 'Transaction rejected by user';
      } else if (err.message?.includes('intrinsic gas too low')) {
        errorMessage = 'Gas limit too low - please try again';
      } else if (err.message?.includes('out of gas')) {
        errorMessage = 'Transaction ran out of gas - try with a smaller amount';
      }
      
      showErrorToast(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  // Handle repay
  const handleRepay = async () => {
    if (!address || !repayAmount) {
      showErrorToast('Please connect wallet and enter amount');
      return;
    }

    // Frontend validation: Check if user has an active loan
    if (Number(loan.amount) <= 0) {
      showErrorToast('You do not have an active loan to repay');
      return;
    }

    // Frontend validation: Check if amount is valid
    if (Number(repayAmount) <= 0) {
      showErrorToast('Please enter a valid amount greater than 0');
      return;
    }

    // Frontend validation: Check if repay amount doesn't exceed total debt
    const totalDebt = Number(loan.amount) + Number(loan.interest);
    if (Number(repayAmount) > totalDebt) {
      showErrorToast(`Repay amount cannot exceed total debt of ${totalDebt.toFixed(6)} USDC`);
      return;
    }

    try {
      setIsLoading(true);
      showInfoToast('Repaying...');

      const amount = parseUnits(repayAmount, 6);

      // Get current loan data to calculate total debt
      const loanData = await directPublicClient.readContract({
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'loans',
        args: [address]
      });

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const principal = (loanData as any)[0] as bigint;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const interest = (loanData as any)[2] as bigint;
      const totalDebt = principal + interest;

      // Approve USDC spending for total debt
      const approveCall = {
        address: USDC_ADDRESS as `0x${string}`,
        abi: erc20Abi,
        functionName: 'approve',
        args: [LENDING_MARKET_ADDRESS, totalDebt],
        account: address
      };

      const approveGas = await estimateGasWithBuffer(approveCall);

      const approveHash = await directWalletClient.writeContract({
        ...approveCall,
        gas: approveGas
      });

      await directPublicClient.waitForTransactionReceipt({ hash: approveHash });

      // Repay
      const repayCall = {
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'repay',
        args: [amount],
        account: address
      };

      const repayGas = await estimateGasWithBuffer(repayCall);

      const repayHash = await directWalletClient.writeContract({
        ...repayCall,
        gas: repayGas
      });

      await directPublicClient.waitForTransactionReceipt({ hash: repayHash });

      // Refresh data
      await fetchUserData(false);
      setRepayAmount('');
      showSuccessToast('Repay successful!');
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } catch (err: any) {
      console.error('Repay error:', err);
      let errorMessage = 'Repay failed';
      
      if (err.message?.includes('insufficient')) {
        errorMessage = 'Insufficient USDC balance';
      } else if (err.message?.includes('gas')) {
        errorMessage = 'Gas estimation failed or insufficient gas';
      } else if (err.message?.includes('rejected')) {
        errorMessage = 'Transaction rejected by user';
      }
      
      showErrorToast(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  // Handle withdraw
  const handleWithdraw = async () => {
    if (!address || !withdrawAmount) {
      showErrorToast('Please connect wallet and enter amount');
      return;
    }

    // Frontend validation: Check if amount is valid
    if (Number(withdrawAmount) <= 0) {
      showErrorToast('Please enter a valid amount greater than 0');
      return;
    }

    // Frontend validation: Check if user has enough balance to withdraw
    if (Number(withdrawAmount) > Number(userStats.balance)) {
      showErrorToast('Insufficient balance to withdraw');
      return;
    }

    try {
      setIsLoading(true);
      showInfoToast('Withdrawing...');

      const amount = parseUnits(withdrawAmount, 6);

      // Withdraw from lending market
      const withdrawCall = {
        address: LENDING_MARKET_ADDRESS as `0x${string}`,
        abi: lendingMarketAbi,
        functionName: 'withdraw',
        args: [amount],
        account: address
      };

      const withdrawGas = await estimateGasWithBuffer(withdrawCall);

      const withdrawHash = await directWalletClient.writeContract({
        ...withdrawCall,
        gas: withdrawGas
      });

      await directPublicClient.waitForTransactionReceipt({ hash: withdrawHash });

      // Refresh data
      await fetchUserData(false);
      setWithdrawAmount('');
      showSuccessToast('Withdraw successful!');
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } catch (err: any) {
      console.error('Withdraw error:', err);
      let errorMessage = 'Withdraw failed';
      
      if (err.message?.includes('insufficient')) {
        errorMessage = 'Insufficient balance to withdraw';
      } else if (err.message?.includes('gas')) {
        errorMessage = 'Gas estimation failed or insufficient gas';
      } else if (err.message?.includes('rejected')) {
        errorMessage = 'Transaction rejected by user';
      }
      
      showErrorToast(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  // Auto-fetch data when wallet connects
  useEffect(() => {
    if (isConnected && address && !isFetchingRef.current && !hasInitialFetchRef.current) {
      hasInitialFetchRef.current = true;
      fetchUserData(false);
    } else if (!isConnected) {
      // Reset flags when wallet disconnects
      hasInitialFetchRef.current = false;
      isFetchingRef.current = false;
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
    withdrawAmount,
    setWithdrawAmount,
    userStats,
    loan,
    isLoading,
    isConnected,
    address,

    // Functions
    fetchUserData,
    handleDeposit,
    handleWithdraw,
    handleBorrow,
    handleRepay,
    calculateRequiredCollateral,
    calculateMaxBorrow
  };
} 