# Stablend - DeFi Lending Platform

A decentralized lending platform built on Mantle Network with AI-powered dynamic interest rates and credit scoring.

## 🏗️ Architecture

- **Smart Contracts**: Solidity contracts deployed on Mantle Network
- **Frontend**: Next.js 15 with TypeScript and Tailwind CSS
- **Off-chain Scripts**: TypeScript scripts for rate updates and data fetching
- **AI Components**: Python-based TensorFlow models for rate prediction

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Yarn (package manager)
- Foundry (for smart contracts)
- Python 3.8+ (for AI components)
- Git

### Installation

1. **Clone and setup submodules**
   ```bash
   git clone <repository-url>
   cd stablend
   git submodule update --init --recursive
   ```

2. **Install frontend dependencies**
   ```bash
   cd frontend
   yarn install
   ```

3. **Install script dependencies**
   ```bash
   cd ../scripts
   yarn install
   ```

4. **Setup Python virtual environment**
   ```bash
   cd ../off-chain/ai
   ./setup_venv.sh
   ```

5. **Setup environment**
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

### Smart Contracts

1. **Compile contracts**
   ```bash
   cd smart-contracts
   forge build
   ```

2. **Run tests**
   ```bash
   forge test
   ```

3. **Deploy contracts** (requires .env configuration)
   ```bash
   forge script script/Deploy.s.sol --rpc-url $MANTLE_SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast
   ```

### Frontend Development

1. **Start development server**
   ```bash
   cd frontend
   yarn dev
   ```

2. **Build for production**
   ```bash
   yarn build
   yarn start
   ```

### Off-chain Scripts

1. **Update credit scores**
   ```bash
   cd scripts
   yarn update-scores
   ```

2. **Fetch market data**
   ```bash
   yarn fetch-data
   ```

3. **Update interest rates**
   ```bash
   yarn update-rates
   ```

### AI Model Training

1. **Activate virtual environment**
   ```bash
   cd off-chain/ai
   source venv/bin/activate
   ```

2. **Train the model**
   ```bash
   python trainModel.py
   ```

3. **Deactivate when done**
   ```bash
   deactivate
   ```

## 📁 Project Structure

```
stablend/
├── frontend/                 # Next.js frontend
│   ├── src/app/             # App router pages
│   ├── public/              # Static assets
│   └── package.json         # Frontend dependencies
├── smart-contracts/         # Solidity contracts
│   ├── src/                 # Contract source files
│   │   ├── mocks/           # Mock token contracts
│   │   │   ├── MockUSDC.sol # Mock USDC token
│   │   │   └── MockMNT.sol  # Mock MNT token
│   │   ├── LendingMarket.sol # Core lending logic
│   │   ├── RateAdjuster.sol # Dynamic rate adjustment
│   │   ├── CreditScore.sol  # Credit scoring system
│   │   └── interfaces/      # Contract interfaces
│   ├── test/                # Comprehensive tests
│   ├── script/              # Deployment scripts
│   └── foundry.toml         # Foundry configuration
├── scripts/                 # TypeScript off-chain scripts
│   ├── updateRates.ts       # Rate update logic
│   ├── fetchMarketData.ts   # Market data fetching
│   └── updateCreditScores.ts # Credit score updates
├── off-chain/               # AI and data components
│   ├── ai/                  # Python AI models
│   │   ├── venv/            # Python virtual environment
│   │   ├── setup_venv.sh    # Virtual environment setup
│   │   └── requirements.txt # Python dependencies
│   └── data/                # Market data
└── env.example              # Environment variables template
```

## 🔧 Configuration

### Environment Variables

Copy `env.example` to `.env` and configure:

- `MANTLE_SEPOLIA_RPC`: Mantle Sepolia RPC URL
- `PRIVATE_KEY`: Your private key for contract interactions
- `MOCK_USDC_ADDRESS`: Deployed mock USDC contract
- `MOCK_MNT_ADDRESS`: Deployed mock MNT contract
- `LENDING_MARKET_ADDRESS`: Deployed lending market contract
- `RATE_ADJUSTER_ADDRESS`: Deployed rate adjuster contract
- `CREDIT_SCORE_ADDRESS`: Deployed credit score contract

### Network Configuration

The platform is configured for Mantle Network:
- **Testnet**: Mantle Sepolia (Chain ID: 5003)
- **Mainnet**: Mantle (Chain ID: 5000)

### Python Environment

The project uses a Python virtual environment to avoid conflicts with system packages:

```bash
# Setup virtual environment (first time only)
cd off-chain/ai
./setup_venv.sh

# Activate virtual environment (each session)
source venv/bin/activate

# Deactivate when done
deactivate
```

## 🧪 Testing

### Smart Contract Tests

Run comprehensive tests for all contracts:

```bash
cd smart-contracts
forge test
```

Tests cover:
- **Mock Tokens**: USDC and MNT token functionality
- **Lending Market**: Deposit, borrow, repay, liquidation
- **Rate Adjuster**: Dynamic rate calculation and updates
- **Credit Score**: Credit scoring system
- **Interest Accrual**: Proper interest calculation
- **Liquidation Logic**: Undercollateralized position handling

### Test Coverage

- ✅ Deposit and withdrawal functionality
- ✅ Borrowing with collateral validation
- ✅ Interest accrual over time
- ✅ Repayment with partial and full amounts
- ✅ Liquidation of undercollateralized positions
- ✅ Dynamic rate adjustment based on credit scores
- ✅ Chainlink price feed integration
- ✅ Access control and security measures

## 🔐 Security Features

### Smart Contract Security

- **Reentrancy Protection**: All external calls protected
- **Access Control**: Owner-only functions for admin operations
- **Price Validation**: Chainlink staleness checks
- **Collateral Validation**: Proper collateral ratio enforcement
- **Liquidation Protection**: Automatic liquidation of risky positions

### Key Security Measures

1. **Collateral Requirements**: 150% minimum collateralization
2. **Liquidation Threshold**: 125% threshold for liquidation
3. **Price Staleness**: 1-hour maximum price staleness
4. **Rate Caps**: Maximum 50% interest rate
5. **Reserve Factor**: 10% reserve for platform stability

## 🤖 AI Integration

### Rate Prediction Model

The platform uses a TensorFlow neural network to predict optimal interest rates based on:

- **Pool Utilization**: Current lending pool usage
- **Credit Score**: User's creditworthiness
- **Market Price**: MNT token price volatility

### Model Training

```bash
cd off-chain/ai
source venv/bin/activate
python trainModel.py
deactivate
```

The model is trained on historical market data and generates synthetic data for testing.

## 📊 Key Features

### Lending & Borrowing

- **Deposit USDC**: Earn interest on deposits
- **Borrow USDC**: Borrow against MNT collateral
- **Dynamic Rates**: AI-powered interest rate adjustment
- **Credit Scoring**: Risk-based rate calculation

### Risk Management

- **Liquidation**: Automatic liquidation of undercollateralized positions
- **Collateral Monitoring**: Real-time collateral ratio tracking
- **Price Feeds**: Chainlink oracle integration for accurate pricing
- **Reserve System**: Platform stability through reserve factors

### User Experience

- **Responsive Design**: Mobile-first interface
- **Real-time Updates**: Live market data and position tracking
- **Wallet Integration**: Seamless wallet connection
- **Transaction History**: Complete transaction tracking

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details
