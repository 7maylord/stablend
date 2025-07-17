'use client';

import { useState } from 'react';
import styles from './page.module.css';

export default function Home() {
  const [activeTab, setActiveTab] = useState('lend');
  const [amount, setAmount] = useState('');
  const [collateral, setCollateral] = useState('');

  return (
    <div className={styles.container}>
      {/* Header */}
      <header className={styles.header}>
        <div className={styles.logo}>
          <h1>Stablend</h1>
          <p>DeFi Lending on Mantle</p>
        </div>
        <div className={styles.walletSection}>
          <button className={styles.connectButton}>
            Connect Wallet
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className={styles.main}>
        <div className={styles.statsGrid}>
          <div className={styles.statCard}>
            <h3>Total Value Locked</h3>
            <p className={styles.statValue}>$0</p>
          </div>
          <div className={styles.statCard}>
            <h3>Total Borrowed</h3>
            <p className={styles.statValue}>$0</p>
          </div>
          <div className={styles.statCard}>
            <h3>APY (Lending)</h3>
            <p className={styles.statValue}>5.0%</p>
          </div>
          <div className={styles.statCard}>
            <h3>APY (Borrowing)</h3>
            <p className={styles.statValue}>7.5%</p>
          </div>
        </div>

        {/* Lending/Borrowing Interface */}
        <div className={styles.interface}>
          <div className={styles.tabContainer}>
            <button 
              className={`${styles.tab} ${activeTab === 'lend' ? styles.active : ''}`}
              onClick={() => setActiveTab('lend')}
            >
              Lend
            </button>
            <button 
              className={`${styles.tab} ${activeTab === 'borrow' ? styles.active : ''}`}
              onClick={() => setActiveTab('borrow')}
            >
              Borrow
            </button>
          </div>

          <div className={styles.formContainer}>
            {activeTab === 'lend' ? (
              <div className={styles.form}>
                <h2>Lend USDC</h2>
                <div className={styles.inputGroup}>
                  <label>Amount (USDC)</label>
                  <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="0.00"
                    className={styles.input}
                  />
                </div>
                <button className={styles.actionButton}>
                  Deposit USDC
                </button>
              </div>
            ) : (
              <div className={styles.form}>
                <h2>Borrow USDC</h2>
                <div className={styles.inputGroup}>
                  <label>Amount to Borrow (USDC)</label>
                  <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="0.00"
                    className={styles.input}
                  />
                </div>
                <div className={styles.inputGroup}>
                  <label>Collateral (MNT)</label>
                  <input
                    type="number"
                    value={collateral}
                    onChange={(e) => setCollateral(e.target.value)}
                    placeholder="0.00"
                    className={styles.input}
                  />
                </div>
                <button className={styles.actionButton}>
                  Borrow USDC
                </button>
              </div>
            )}
          </div>
        </div>

        {/* Market Data */}
        <div className={styles.marketData}>
          <h2>Market Data</h2>
          <div className={styles.dataGrid}>
            <div className={styles.dataItem}>
              <span>MNT Price:</span>
              <span>$1.20</span>
            </div>
            <div className={styles.dataItem}>
              <span>Pool Utilization:</span>
              <span>0%</span>
            </div>
            <div className={styles.dataItem}>
              <span>Your Credit Score:</span>
              <span>500</span>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
