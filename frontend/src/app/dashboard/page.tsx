'use client'

import { useAccount, useDisconnect } from 'wagmi'
import { useAppKit } from '@reown/appkit/react'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useContracts } from '@/hooks/useContracts'
import { showInfoToast, showSuccessToast, showWarningToast } from '@/components/ToastContainer'

export default function Dashboard() {
  const { address, isConnected } = useAccount()
  const { disconnect } = useDisconnect()
  const { open } = useAppKit()
  const [activeTab, setActiveTab] = useState('lend')
  
  // Contract interactions
  const {
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
    handleDeposit,
    handleBorrow,
    handleRepay,
    fetchUserData
  } = useContracts()

  const shortenAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50">
      {/* Header */}
      <header className="bg-white/80 backdrop-blur-md border-b border-gray-200 sticky top-0 z-50">
        <div className="container-responsive">
          <div className="flex justify-between items-center h-16">
            {/* Logo */}
            <div className="flex items-center">
              <Link href="/" className="cursor-pointer">
                <h1 className="text-2xl font-bold text-gradient hover:opacity-80 transition-opacity">
                  Stablend
                </h1>
              </Link>
            </div>

            {/* Wallet Connection */}
            <div className="flex items-center space-x-4">
              {isConnected ? (
                <div className="flex items-center space-x-3">
                  <button
                    onClick={() => {
                      fetchUserData();
                      showInfoToast('Refreshing your data... 🔄');
                    }}
                    disabled={isLoading}
                    className="px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors disabled:opacity-50"
                  >
                    {isLoading ? 'Loading...' : 'Refresh'}
                  </button>
                  <div className="flex items-center space-x-2 bg-gray-100 px-3 py-2 rounded-lg">
                    <div className="status-connected"></div>
                    <span className="text-sm font-medium text-gray-700">
                      {shortenAddress(address!)}
                    </span>
                  </div>
                  <button
                    onClick={() => disconnect()}
                    className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
                  >
                    Disconnect
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => open()}
                  className="btn-gradient"
                >
                  Connect Wallet
                </button>
              )}
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container-responsive py-8">
        {!isConnected ? (
          // Not Connected State
          <div className="text-center py-20">
            <div className="max-w-md mx-auto">
              <div className="w-24 h-24 gradient-blue-purple rounded-full flex items-center justify-center mx-auto mb-6">
                <svg className="w-12 h-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </div>
              <h2 className="text-responsive-lg font-bold text-gray-900 mb-4">
                Connect Your Wallet
              </h2>
              <p className="text-lg text-gray-600 mb-8">
                Connect your wallet to start lending and borrowing on Stablend
              </p>
              <button
                onClick={() => open()}
                className="btn-gradient"
              >
                Connect Wallet
              </button>
            </div>
          </div>
        ) : (
          // Connected State - Dashboard
          <div className="space-y-8">
            {/* Welcome Section */}
            <div className="card">
              <div className="flex items-center justify-between">
                <div>
                  <h1 className="text-responsive-lg font-bold text-gray-900 mb-2">
                    Welcome back!
                  </h1>
                  <p className="text-gray-600">
                    Ready to start your DeFi journey? Deposit assets to earn interest or borrow against your collateral.
                  </p>
                </div>
                <div className="text-right">
                  <div className="text-2xl font-bold text-green-600">
                    ${userStats.balance}
                  </div>
                  <div className="text-sm text-gray-500">Total Portfolio Value</div>
                </div>
              </div>
            </div>

            {/* Quick Stats */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="card card-hover-effect">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-500">Total Deposited</p>
                    <p className="text-2xl font-bold text-gray-900">${userStats.balance}</p>
                  </div>
                  <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                    <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                    </svg>
                  </div>
                </div>
              </div>

              <div className="card card-hover-effect">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-500">Credit Score</p>
                    <p className="text-2xl font-bold text-gray-900">{userStats.creditScore}</p>
                  </div>
                  <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
                    <svg className="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                </div>
              </div>

              <div className="card card-hover-effect">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-500">Interest Rate</p>
                    <p className="text-2xl font-bold text-gray-900">{userStats.rate}%</p>
                  </div>
                  <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                    <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                    </svg>
                  </div>
                </div>
              </div>
            </div>

            {/* Action Tabs */}
            <div className="card">
              <div className="border-b border-gray-200">
                <nav className="flex space-x-8 px-8">
                  <button
                    onClick={() => setActiveTab('lend')}
                    className={`py-4 px-1 border-b-2 font-medium text-sm ${
                      activeTab === 'lend'
                        ? 'tab-active'
                        : 'tab-inactive'
                    }`}
                  >
                    Lend
                  </button>
                  <button
                    onClick={() => setActiveTab('borrow')}
                    className={`py-4 px-1 border-b-2 font-medium text-sm ${
                      activeTab === 'borrow'
                        ? 'tab-active'
                        : 'tab-inactive'
                    }`}
                  >
                    Borrow
                  </button>
                </nav>
              </div>

              <div className="p-8">
                {activeTab === 'lend' ? (
                  <div className="space-y-6">
                    <div>
                      <h3 className="text-xl font-semibold text-gray-900 mb-4">Lend Assets</h3>
                      <p className="text-gray-600 mb-6">
                        Deposit your assets to earn interest. Choose from our supported tokens below.
                      </p>
                    </div>

                    {/* Error Display */}
                    {error && (
                      <div className="bg-red-50 border border-red-200 rounded-xl p-4">
                        <div className="flex items-center space-x-3">
                          <div className="w-8 h-8 bg-red-100 rounded-full flex items-center justify-center">
                            <svg className="w-4 h-4 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
                            </svg>
                          </div>
                          <div>
                            <h4 className="font-semibold text-red-800">Transaction Failed</h4>
                            <p className="text-red-700 text-sm">{error}</p>
                          </div>
                        </div>
                      </div>
                    )}

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      <div className="border border-gray-200 rounded-xl p-6 hover:border-blue-300 transition-colors card-hover-effect">
                        <div className="flex items-center justify-between mb-4">
                          <div className="flex items-center space-x-3">
                            <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                              <span className="text-blue-600 font-semibold">$</span>
                            </div>
                            <div>
                              <h4 className="font-semibold text-gray-900">USDC</h4>
                              <p className="text-sm text-gray-500">USD Coin</p>
                            </div>
                          </div>
                          <div className="text-right">
                            <div className="text-lg font-semibold text-green-600">{userStats.rate}%</div>
                            <div className="text-sm text-gray-500">APY</div>
                          </div>
                        </div>
                        
                        <div className="space-y-4">
                          <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                              Amount to Deposit
                            </label>
                            <input
                              type="number"
                              placeholder="0.00"
                              value={depositAmount}
                              onChange={(e) => setDepositAmount(e.target.value)}
                              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            />
                          </div>
                          <button 
                            onClick={handleDeposit}
                            disabled={isLoading || !depositAmount}
                            className="w-full btn-gradient disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            {isLoading ? 'Processing...' : 'Deposit USDC'}
                          </button>
                        </div>
                      </div>

                      <div className="border border-gray-200 rounded-xl p-6 hover:border-purple-300 transition-colors card-hover-effect">
                        <div className="flex items-center justify-between mb-4">
                          <div className="flex items-center space-x-3">
                            <div className="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center">
                              <span className="text-purple-600 font-semibold">M</span>
                            </div>
                            <div>
                              <h4 className="font-semibold text-gray-900">MNT</h4>
                              <p className="text-sm text-gray-500">Mantle Token</p>
                            </div>
                          </div>
                          <div className="text-right">
                            <div className="text-lg font-semibold text-green-600">3.8%</div>
                            <div className="text-sm text-gray-500">APY</div>
                          </div>
                        </div>
                        <div className="text-center text-gray-500">
                          <p>MNT deposits coming soon!</p>
                        </div>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-6">
                    <div>
                      <h3 className="text-xl font-semibold text-gray-900 mb-4">Borrow Assets</h3>
                      <p className="text-gray-600 mb-6">
                        Borrow against your collateral. You'll need to deposit assets first to borrow.
                      </p>
                    </div>

                    {/* Error Display */}
                    {error && (
                      <div className="bg-red-50 border border-red-200 rounded-xl p-4">
                        <div className="flex items-center space-x-3">
                          <div className="w-8 h-8 bg-red-100 rounded-full flex items-center justify-center">
                            <svg className="w-4 h-4 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
                            </svg>
                          </div>
                          <div>
                            <h4 className="font-semibold text-red-800">Transaction Failed</h4>
                            <p className="text-red-700 text-sm">{error}</p>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* Loan Information */}
                    {Number(loan.amount) > 0 ? (
                      <div className="bg-blue-50 border border-blue-200 rounded-xl p-6">
                        <h4 className="font-semibold text-blue-800 mb-4">Current Loan</h4>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
                          <div>
                            <p className="text-sm text-blue-600">Borrowed Amount</p>
                            <p className="text-lg font-semibold text-blue-800">${loan.amount} USDC</p>
                          </div>
                          <div>
                            <p className="text-sm text-blue-600">Collateral</p>
                            <p className="text-lg font-semibold text-blue-800">{loan.collateral} MNT</p>
                          </div>
                          <div>
                            <p className="text-sm text-blue-600">Interest Accrued</p>
                            <p className="text-lg font-semibold text-blue-800">${loan.interest} USDC</p>
                          </div>
                          <div>
                            <p className="text-sm text-blue-600">Interest Rate</p>
                            <p className="text-lg font-semibold text-blue-800">{(Number(loan.rate) / 100).toFixed(2)}%</p>
                          </div>
                        </div>
                        
                        <div className="space-y-4">
                          <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                              Amount to Repay
                            </label>
                            <input
                              type="number"
                              placeholder="0.00"
                              value={repayAmount}
                              onChange={(e) => setRepayAmount(e.target.value)}
                              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            />
                          </div>
                          <button 
                            onClick={handleRepay}
                            disabled={isLoading || !repayAmount}
                            className="w-full btn-gradient disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            {isLoading ? 'Processing...' : 'Repay Loan'}
                          </button>
                        </div>
                      </div>
                    ) : (
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <div className="border border-gray-200 rounded-xl p-6 hover:border-purple-300 transition-colors card-hover-effect">
                          <div className="flex items-center justify-between mb-4">
                            <div className="flex items-center space-x-3">
                              <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                                <span className="text-blue-600 font-semibold">$</span>
                              </div>
                              <div>
                                <h4 className="font-semibold text-gray-900">USDC</h4>
                                <p className="text-sm text-gray-500">USD Coin</p>
                              </div>
                            </div>
                            <div className="text-right">
                              <div className="text-lg font-semibold text-green-600">{userStats.rate}%</div>
                              <div className="text-sm text-gray-500">APR</div>
                            </div>
                          </div>
                          
                          <div className="space-y-4">
                            <div>
                              <label className="block text-sm font-medium text-gray-700 mb-2">
                                Amount to Borrow
                              </label>
                              <input
                                type="number"
                                placeholder="0.00"
                                value={borrowAmount}
                                onChange={(e) => {
                                  setBorrowAmount(e.target.value);
                                  // Calculate required collateral based on USDC amount
                                  if (e.target.value && Number(userStats.mntPrice) > 0) {
                                    const usdcAmount = Number(e.target.value);
                                    const mntPrice = Number(userStats.mntPrice);
                                    // 150% collateralization ratio (from smart contract)
                                    const requiredCollateral = (usdcAmount * 1.5) / mntPrice;
                                    setCollateralAmount(requiredCollateral.toFixed(6));
                                  } else {
                                    setCollateralAmount('');
                                  }
                                }}
                                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                              />
                            </div>
                            <div>
                              <label className="block text-sm font-medium text-gray-700 mb-2">
                                MNT Collateral (Required: 150%)
                              </label>
                              <input
                                type="number"
                                placeholder="0.00"
                                value={collateralAmount}
                                onChange={(e) => {
                                  setCollateralAmount(e.target.value);
                                  // Calculate maximum USDC that can be borrowed based on MNT collateral
                                  if (e.target.value && Number(userStats.mntPrice) > 0) {
                                    const mntAmount = Number(e.target.value);
                                    const mntPrice = Number(userStats.mntPrice);
                                    // 150% collateralization ratio means max borrow = (collateral * price) / 1.5
                                    const maxBorrow = (mntAmount * mntPrice) / 1.5;
                                    setBorrowAmount(maxBorrow.toFixed(6));
                                  } else {
                                    setBorrowAmount('');
                                  }
                                }}
                                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                              />
                              {borrowAmount && Number(userStats.mntPrice) > 0 && (
                                <div className="text-xs text-gray-500 mt-1 space-y-1">
                                  <p>Based on MNT price: ${userStats.mntPrice}</p>
                                  <p>Collateralization ratio: 150%</p>
                                  {collateralAmount && (
                                    <p>Collateral value: ${(Number(collateralAmount) * Number(userStats.mntPrice)).toFixed(2)}</p>
                                  )}
                                </div>
                              )}
                            </div>
                            <button 
                              onClick={handleBorrow}
                              disabled={isLoading || !borrowAmount || !collateralAmount}
                              className="w-full btn-gradient disabled:opacity-50 disabled:cursor-not-allowed"
                            >
                              {isLoading ? 'Processing...' : 'Borrow USDC'}
                            </button>
                          </div>
                        </div>

                        <div className="bg-yellow-50 border border-yellow-200 rounded-xl p-6">
                          <div className="flex items-center space-x-3">
                            <div className="w-8 h-8 bg-yellow-100 rounded-full flex items-center justify-center">
                              <svg className="w-4 h-4 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
                              </svg>
                            </div>
                            <div>
                              <h4 className="font-semibold text-yellow-800">Borrowing Requirements</h4>
                              <ul className="text-yellow-700 text-sm mt-2 space-y-1">
                                <li>• 150% collateralization ratio</li>
                                <li>• MNT price: ${userStats.mntPrice}</li>
                                <li>• Credit score: {userStats.creditScore}</li>
                                <li>• Interest rate: {userStats.rate}%</li>
                              </ul>
                            </div>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  )
} 