#!/bin/bash

# Stablend Project Setup Script (Yarn Version)

echo "🚀 Setting up Stablend DeFi Lending Platform with Yarn..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "smart-contracts" ] || [ ! -d "frontend" ]; then
    print_error "Please run this script from the stablend project root directory"
    exit 1
fi

# Check prerequisites
print_step "Checking prerequisites..."

# Check Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    print_error "Node.js version 18+ is required. Current version: $(node --version)"
    exit 1
fi

print_status "Node.js version: $(node --version)"

# Check Yarn
if ! command -v yarn &> /dev/null; then
    print_warning "Yarn is not installed. Installing Yarn..."
    npm install -g yarn
fi

YARN_VERSION=$(yarn --version)
print_status "Yarn version: $YARN_VERSION"

# Check Foundry
if ! command -v forge &> /dev/null; then
    print_warning "Foundry is not installed. Installing Foundry..."
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    foundryup
fi

FORGE_VERSION=$(forge --version | head -n1)
print_status "Foundry version: $FORGE_VERSION"

# Check Python
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3.8+ first."
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
print_status "Python version: $(python3 --version)"

print_status "All prerequisites are satisfied!"

# Setup Git submodules
print_step "Setting up Git submodules..."
git submodule update --init --recursive

# Setup frontend
print_step "Setting up frontend dependencies..."
cd frontend
yarn install --frozen-lockfile
cd ..

# Setup scripts
print_step "Setting up script dependencies..."
cd scripts
yarn install --frozen-lockfile
cd ..

# Setup smart contracts
print_step "Setting up smart contracts..."
cd smart-contracts
forge build
cd ..

# Setup Python environment
print_step "Setting up Python virtual environment..."
cd off-chain/ai
./setup_venv.sh
cd ../..

# Setup environment file
if [ ! -f ".env" ]; then
    print_status "Creating .env file from template..."
    cp env.example .env
    print_warning "Please edit .env file with your configuration"
else
    print_status ".env file already exists"
fi

# Make scripts executable
print_step "Making scripts executable..."
chmod +x off-chain/ai/setup_venv.sh
chmod +x off-chain/ai/run_model.sh
chmod +x setup.sh

# Create .yarnrc.yml for better Yarn configuration
if [ ! -f ".yarnrc.yml" ]; then
    print_status "Creating Yarn configuration..."
    cat > .yarnrc.yml << EOF
nodeLinker: node-modules
enableGlobalCache: true
compressionLevel: mixed
logFilters:
  - code: YN0002
    level: discard
  - code: YN0060
    level: discard
  - code: YN0006
    level: discard
  - code: YN0076
    level: discard
EOF
fi

print_status "Setup complete! 🎉"
echo ""
echo "📋 Next steps:"
echo "1. Edit .env file with your configuration"
echo "2. Run tests: cd smart-contracts && forge test"
echo "3. Deploy contracts: cd smart-contracts && forge script script/Deploy.s.sol --rpc-url \$MANTLE_SEPOLIA_RPC --private-key \$PRIVATE_KEY --broadcast"
echo "4. Start frontend: cd frontend && yarn dev"
echo "5. Train AI model: cd off-chain/ai && source venv/bin/activate && python trainModel.py"
echo ""
echo "🔧 Useful commands:"
echo "- yarn dev (frontend development)"
echo "- yarn build (frontend production build)"
echo "- yarn lint (code linting)"
echo "- forge test (smart contract tests)"
echo "- forge build (compile contracts)"
echo ""
echo "📚 For more information, see README.md" 