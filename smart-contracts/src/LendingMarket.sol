// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RateAdjuster.sol";
import "./interfaces/IChainlinkOracle.sol";

contract LendingMarket is ReentrancyGuard, Ownable {
    IERC20 public usdc; // Mock USDC
    IERC20 public collateralToken; // MNT
    RateAdjuster public rateAdjuster;
    AggregatorV3Interface public chainlinkFeed; // Chainlink MNT/USD feed

    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateralization
    uint256 public constant LIQUIDATION_THRESHOLD = 125; // 125% threshold for liquidation
    uint256 public constant LIQUIDATION_PENALTY = 10; // 10% penalty for liquidators
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public lastUpdateTime;
    uint256 public reserveFactor = 1000; // 10% reserve factor (basis points)

    struct Loan {
        uint256 amount;
        uint256 collateral;
        uint256 interestAccrued;
        uint256 startTime;
        uint256 rate; // Basis points
        uint256 lastAccrualTime;
        bool isActive;
    }

    struct LiquidationInfo {
        uint256 collateralToLiquidate;
        uint256 debtToRepay;
        uint256 liquidatorReward;
    }

    mapping(address => uint256) public lenderBalances;
    mapping(address => Loan) public loans;
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userBorrows;

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount, uint256 collateral);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed user, address indexed liquidator, uint256 collateralLiquidated, uint256 debtRepaid);
    event InterestAccrued(address indexed user, uint256 interest);
    event ReserveFactorUpdated(uint256 newReserveFactor);

    constructor(address _usdc, address _collateralToken, address _rateAdjuster, address _chainlinkFeed)
        Ownable(msg.sender)
    {
        usdc = IERC20(_usdc);
        collateralToken = IERC20(_collateralToken);
        rateAdjuster = RateAdjuster(_rateAdjuster);
        chainlinkFeed = AggregatorV3Interface(_chainlinkFeed);
        lastUpdateTime = block.timestamp;
    }

    // Modifier to update interest accrual
    modifier updateInterest(address user) {
        if (loans[user].isActive) {
            _accrueInterest(user);
        }
        _;
    }

    // Deposit USDC to earn interest
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        lenderBalances[msg.sender] += amount;
        userDeposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposit(msg.sender, amount);
    }

    // Withdraw USDC from deposits
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(lenderBalances[msg.sender] >= amount, "Insufficient balance");

        lenderBalances[msg.sender] -= amount;
        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;

        require(usdc.transfer(msg.sender, amount), "Transfer failed");
        emit Withdraw(msg.sender, amount);
    }

    // Borrow USDC with MNT collateral
    function borrow(uint256 amount, uint256 collateral) external nonReentrant updateInterest(msg.sender) {
    require(amount > 0 && collateral > 0, "Invalid amounts");
    require(!loans[msg.sender].isActive, "Active loan exists");

    // Check if there's enough liquidity
    require(totalDeposits >= totalBorrows + amount, "Insufficient liquidity");

    // Get current MNT price from Chainlink
    (, int256 price,,, uint256 updatedAt) = chainlinkFeed.latestRoundData();
    require(price > 0, "Invalid price");
    require(block.timestamp - updatedAt < 3600, "Stale price"); // 1 hour staleness

    // Convert price to uint256 for calculations
    uint256 mntPriceUsd = uint256(price); // Price in 8 decimals (e.g., $1.50 = 150000000)

    // Calculate collateral value safely
    // collateral is in 18 decimals, price is in 8 decimals
    // We want result in 18 decimals to match USDC scaled up
    uint256 collateralValueUsd18; // Will be in 18 decimal USD
    
    // Use OpenZeppelin's SafeMath-like approach or check for overflow
    // collateral (18 decimals) * price (8 decimals) / 1e8 = USD value (18 decimals)
    
    // First check if multiplication would overflow
    require(collateral <= type(uint256).max / mntPriceUsd, "Collateral value overflow");
    
    // Safe calculation: (collateral * price) / 1e8
    // This gives us USD value in 18 decimals
    collateralValueUsd18 = (collateral * mntPriceUsd) / 1e8;

    // Calculate required collateral value
    // amount is in 6 decimals (USDC), scale to 18 decimals for comparison
    // Then apply 150% collateralization ratio
    uint256 borrowAmountUsd18 = amount * 1e12; // Scale 6 decimals to 18 decimals
    uint256 requiredCollateralUsd18 = (borrowAmountUsd18 * COLLATERAL_RATIO) / 100;

    require(collateralValueUsd18 >= requiredCollateralUsd18, "Insufficient collateral");

    // Create loan
    loans[msg.sender] = Loan({
        amount: amount,
        collateral: collateral,
        interestAccrued: 0,
        startTime: block.timestamp,
        rate: rateAdjuster.getUserRate(msg.sender),
        lastAccrualTime: block.timestamp,
        isActive: true
    });

    userBorrows[msg.sender] = amount;
    totalBorrows += amount;

    // Transfer tokens
    require(usdc.transfer(msg.sender, amount), "USDC transfer failed");
    require(collateralToken.transferFrom(msg.sender, address(this), collateral), "Collateral transfer failed");

    emit Borrow(msg.sender, amount, collateral);
}
    // Repay loan
    function repay(uint256 amount) external nonReentrant updateInterest(msg.sender) {
        Loan storage loan = loans[msg.sender];
        require(loan.isActive, "No active loan");
        require(amount > 0, "Invalid amount");
        require(amount <= loan.amount + loan.interestAccrued, "Amount exceeds debt");

        uint256 totalDebt = loan.amount + loan.interestAccrued;
        uint256 remainingDebt = totalDebt - amount;

        // Transfer USDC from user
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Update loan
        if (remainingDebt == 0) {
            // Loan fully repaid
            require(collateralToken.transfer(msg.sender, loan.collateral), "Collateral transfer failed");
            delete loans[msg.sender];
            userBorrows[msg.sender] = 0;
            totalBorrows -= loan.amount;
        } else {
            // Partial repayment
            loan.amount = remainingDebt;
            loan.interestAccrued = 0;
            loan.lastAccrualTime = block.timestamp;
            userBorrows[msg.sender] = remainingDebt;
            totalBorrows -= (totalDebt - remainingDebt);
        }

        emit Repay(msg.sender, amount);
    }

    // Liquidate undercollateralized positions
    function liquidate(address user) external nonReentrant updateInterest(user) {
    Loan storage loan = loans[user];
    require(loan.isActive, "No active loan");

    // Get current MNT price
    (, int256 price,,, uint256 updatedAt) = chainlinkFeed.latestRoundData();
    require(price > 0, "Invalid price");
    require(block.timestamp - updatedAt < 3600, "Stale price");

    uint256 mntPriceUsd = uint256(price); // 8 decimals

    // Calculate collateral value safely (same as borrow function)
    require(loan.collateral <= type(uint256).max / mntPriceUsd, "Collateral value overflow");
    uint256 collateralValueUsd18 = (loan.collateral * mntPriceUsd) / 1e8;

    // Calculate total debt and required collateral for liquidation threshold
    uint256 totalDebt = loan.amount + loan.interestAccrued;
    uint256 totalDebtUsd18 = totalDebt * 1e12; // Scale to 18 decimals
    uint256 requiredCollateralUsd18 = (totalDebtUsd18 * LIQUIDATION_THRESHOLD) / 100;

    require(collateralValueUsd18 < requiredCollateralUsd18, "Not undercollateralized");

    // Calculate liquidation amounts
    LiquidationInfo memory liquidation = _calculateLiquidation(loan, mntPriceUsd);

    // Transfer debt repayment from liquidator
    require(usdc.transferFrom(msg.sender, address(this), liquidation.debtToRepay), "Debt transfer failed");

    // Transfer collateral to liquidator (includes penalty)
    require(collateralToken.transfer(msg.sender, liquidation.collateralToLiquidate), "Collateral transfer failed");

    // Update loan - reduce both debt and collateral
    uint256 debtReduction = liquidation.debtToRepay;
    loan.collateral -= liquidation.collateralToLiquidate;

    if (debtReduction >= totalDebt) {
        // Full liquidation
        totalBorrows -= loan.amount;
        userBorrows[user] = 0;

        // Return any remaining collateral to user
        if (loan.collateral > 0) {
            require(collateralToken.transfer(user, loan.collateral), "Remaining collateral transfer failed");
        }
        delete loans[user];
    } else {
        // Partial liquidation
        loan.amount = totalDebt - debtReduction;
        loan.interestAccrued = 0;
        loan.lastAccrualTime = block.timestamp;

        totalBorrows -= debtReduction;
        userBorrows[user] = loan.amount;
    }

    emit Liquidate(user, msg.sender, liquidation.collateralToLiquidate, liquidation.debtToRepay);
}

// Fixed liquidation calculation helper
function _calculateLiquidation(Loan storage loan, uint256 mntPriceUsd) internal view returns (LiquidationInfo memory) {
    uint256 totalDebt = loan.amount + loan.interestAccrued;

    // Calculate maximum liquidatable debt (50% for partial liquidation)
    uint256 maxLiquidatableDebt = totalDebt / 2;
    if (maxLiquidatableDebt == 0) {
        maxLiquidatableDebt = totalDebt; // If debt is small, liquidate all
    }

    // Calculate collateral needed to cover debt
    // Convert debt from 6 decimals to 18 decimals, then to MNT amount
    uint256 debtValueUsd18 = maxLiquidatableDebt * 1e12;
    
    // Check for overflow before calculation
    require(debtValueUsd18 <= type(uint256).max / 1e8, "Debt value overflow");
    uint256 collateralNeeded = (debtValueUsd18 * 1e8) / mntPriceUsd;

    // Add liquidation penalty (liquidator gets extra collateral)
    uint256 penaltyCollateral = (collateralNeeded * LIQUIDATION_PENALTY) / 100;
    uint256 totalCollateralToLiquidate = collateralNeeded + penaltyCollateral;

    // Don't liquidate more collateral than available
    if (totalCollateralToLiquidate > loan.collateral) {
        totalCollateralToLiquidate = loan.collateral;

        // Recalculate debt to repay based on available collateral
        require(loan.collateral <= type(uint256).max / mntPriceUsd, "Available collateral overflow");
        uint256 collateralValueUsd18 = (loan.collateral * mntPriceUsd) / 1e8;
        
        // Account for penalty: liquidator pays less debt but gets penalty bonus
        uint256 debtToCoverUsd18 = (collateralValueUsd18 * 100) / (100 + LIQUIDATION_PENALTY);
        maxLiquidatableDebt = debtToCoverUsd18 / 1e12; // Scale back to 6 decimals

        if (maxLiquidatableDebt > totalDebt) {
            maxLiquidatableDebt = totalDebt;
        }
    }

    return LiquidationInfo({
        collateralToLiquidate: totalCollateralToLiquidate,
        debtToRepay: maxLiquidatableDebt,
        liquidatorReward: penaltyCollateral
    });
}

    // Accrue interest for a user
    function _accrueInterest(address user) internal {
        Loan storage loan = loans[user];
        if (!loan.isActive) return;

        uint256 timeElapsed = block.timestamp - loan.lastAccrualTime;
        if (timeElapsed == 0) return;

        uint256 interest = (loan.amount * loan.rate * timeElapsed) / (SECONDS_PER_YEAR * 10000);
        loan.interestAccrued += interest;
        loan.lastAccrualTime = block.timestamp;

        emit InterestAccrued(user, interest);
    }

    // View functions
    function getLoanInfo(address user) external view returns (Loan memory) {
        return loans[user];
    }

    function getTotalDebt(address user) external view returns (uint256) {
        Loan storage loan = loans[user];
        if (!loan.isActive) return 0;

        uint256 timeElapsed = block.timestamp - loan.lastAccrualTime;
        uint256 interest = (loan.amount * loan.rate * timeElapsed) / (SECONDS_PER_YEAR * 10000);
        return loan.amount + loan.interestAccrued + interest;
    }

    function getCollateralRatio(address user) external view returns (uint256) {
        Loan storage loan = loans[user];
        if (!loan.isActive) return 0;

        (, int256 price,,,) = chainlinkFeed.latestRoundData();
        if (price <= 0) return 0;

        uint256 collateralValue = (loan.collateral * uint256(price)) / 1e8;
        uint256 totalDebt = loan.amount + loan.interestAccrued;

        if (totalDebt == 0) return type(uint256).max;
        return (collateralValue * 100) / totalDebt;
    }

    function getUtilizationRate() external view returns (uint256) {
        if (totalDeposits == 0) return 0;
        return (totalBorrows * 10000) / totalDeposits; // Basis points
    }

    // Admin functions
    function setReserveFactor(uint256 newReserveFactor) external onlyOwner {
        require(newReserveFactor <= 2000, "Reserve factor too high"); // Max 20%
        reserveFactor = newReserveFactor;
        emit ReserveFactorUpdated(newReserveFactor);
    }

    function setChainlinkFeed(address newFeed) external onlyOwner {
        chainlinkFeed = AggregatorV3Interface(newFeed);
    }
}
