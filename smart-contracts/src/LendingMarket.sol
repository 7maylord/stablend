// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./RateAdjuster.sol";
import "./interfaces/IChainlinkOracle.sol";

/**
 * @title LendingMarket
 * @dev Secure lending protocol with overcollateralized loans
 * @notice This contract allows users to deposit USDC, borrow USDC with MNT collateral
 */
contract LendingMarket is ReentrancyGuard, Ownable, Pausable {
    using Math for uint256;

    // Immutable tokens
    IERC20 public immutable usdc;
    IERC20 public immutable collateralToken;
    RateAdjuster public immutable rateAdjuster;
    AggregatorV3Interface public chainlinkFeed;

    // Protocol constants
    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateralization
    uint256 public constant LIQUIDATION_THRESHOLD = 125; // 125% threshold
    uint256 public constant LIQUIDATION_PENALTY = 10; // 10% penalty
    uint256 public constant MAX_LIQUIDATION_RATIO = 50; // Max 50% liquidation per tx
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_INTEREST_RATE = 10000; // 100% max APR
    uint256 public constant PRICE_STALENESS_THRESHOLD = 600; // 10 minutes
    uint256 public constant MIN_PRICE = 1e6; // $0.01 minimum
    uint256 public constant MAX_PRICE = 1e12; // $10,000 maximum
    uint256 public constant MAX_PRICE_CHANGE = 50; // 50% max price change per update
    uint256 public constant MIN_LOAN_AMOUNT = 1e6; // $1 minimum loan
    uint256 public constant MAX_LOAN_AMOUNT = 1e12; // $1M maximum loan
    uint256 public constant FLASH_LOAN_PROTECTION_BLOCKS = 1; // Minimum blocks between borrow/liquidate

    // Protocol state
    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public totalReserves;
    uint256 public lastUpdateTime;
    uint256 public reserveFactor = 1000; // 10% reserve factor (basis points)
    uint256 public lastPrice;
    bool public flashLoanProtectionEnabled = true;

    // Governance timelock
    uint256 public constant TIMELOCK_DELAY = 2 days;
    mapping(bytes32 => uint256) public timelockScheduled;

    struct Loan {
        uint256 amount;
        uint256 collateral;
        uint256 interestAccrued;
        uint256 startTime;
        uint256 rate;
        uint256 lastAccrualTime;
        uint256 lastActionBlock; // Flash loan protection
        bool isActive;
    }

    struct LiquidationInfo {
        uint256 collateralToLiquidate;
        uint256 debtToRepay;
        uint256 liquidatorReward;
        uint256 protocolFee;
    }

    struct ProtocolHealth {
        uint256 totalDepositsAmount;
        uint256 totalBorrowsAmount;
        uint256 totalReservesAmount;
        uint256 utilizationRate;
        uint256 availableLiquidity;
        uint256 currentPrice;
        bool isHealthy;
    }

    // User mappings
    mapping(address => uint256) public lenderBalances;
    mapping(address => Loan) public loans;
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userBorrows;
    mapping(address => uint256) public lastUserAction; // Flash loan protection

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount, uint256 collateral, uint256 rate);
    event Repay(address indexed user, uint256 amount, uint256 remainingDebt);
    event Liquidate(
        address indexed borrower, 
        address indexed liquidator, 
        uint256 collateralLiquidated, 
        uint256 debtRepaid,
        uint256 liquidatorReward,
        uint256 protocolFee
    );
    event InterestAccrued(address indexed user, uint256 interest);
    event ReserveFactorUpdated(uint256 oldFactor, uint256 newFactor);
    event ChainlinkFeedUpdated(address indexed oldFeed, address indexed newFeed);
    event EmergencyAction(string action, address indexed user, uint256 amount);
    event ProtocolHealthCheck(bool isHealthy, uint256 utilizationRate);
    event TimelockScheduled(bytes32 indexed operation, uint256 timestamp);
    event TimelockExecuted(bytes32 indexed operation);

    // Custom errors
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error ActiveLoanExists();
    error NoActiveLoan();
    error InvalidPrice();
    error PriceStale();
    error PriceOutOfBounds();
    error PriceChangeExcessive();
    error InterestRateTooHigh();
    error FlashLoanProtection();
    error LiquidationNotAllowed();
    error TimelockNotReady();
    error InvalidAddress();
    error TransferFailed();

    constructor(
        address _usdc,
        address _collateralToken,
        address _rateAdjuster,
        address _chainlinkFeed
    ) Ownable(msg.sender) {
        if (_usdc == address(0) || 
            _collateralToken == address(0) || 
            _rateAdjuster == address(0) || 
            _chainlinkFeed == address(0)) {
            revert InvalidAddress();
        }

        usdc = IERC20(_usdc);
        collateralToken = IERC20(_collateralToken);
        rateAdjuster = RateAdjuster(_rateAdjuster);
        chainlinkFeed = AggregatorV3Interface(_chainlinkFeed);
        lastUpdateTime = block.timestamp;
        
        // Initialize with current price
        lastPrice = getValidatedPrice();
    }

    modifier updateInterest(address user) {
        if (loans[user].isActive) {
            _accrueInterest(user);
        }
        _;
    }

    modifier flashLoanProtection(address user) {
        if (flashLoanProtectionEnabled) {
            if (block.number <= loans[user].lastActionBlock + FLASH_LOAN_PROTECTION_BLOCKS) {
                revert FlashLoanProtection();
            }
            if (block.number <= lastUserAction[user] + FLASH_LOAN_PROTECTION_BLOCKS) {
                revert FlashLoanProtection();
            }
        }
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }

    /**
     * @dev Get validated price with comprehensive checks and circuit breakers
     */
    function getValidatedPrice() public view returns (uint256) {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = chainlinkFeed.latestRoundData();

        // Basic validation
        if (price <= 0) revert InvalidPrice();
        if (updatedAt == 0 || startedAt == 0) revert InvalidPrice();
        if (block.timestamp - updatedAt > PRICE_STALENESS_THRESHOLD) revert PriceStale();
        if (answeredInRound < roundId) revert PriceStale();

        uint256 currentPrice = uint256(price);
        
        // Bounds check
        if (currentPrice < MIN_PRICE || currentPrice > MAX_PRICE) {
            revert PriceOutOfBounds();
        }

        // Circuit breaker: check for excessive price changes
        if (lastPrice > 0) {
            uint256 priceChange = currentPrice > lastPrice 
                ? ((currentPrice - lastPrice) * 100) / lastPrice
                : ((lastPrice - currentPrice) * 100) / lastPrice;
                
            if (priceChange > MAX_PRICE_CHANGE) {
                revert PriceChangeExcessive();
            }
        }

        return currentPrice;
    }

    /**
     * @dev Calculate collateral value with overflow protection
     */
    function calculateCollateralValue(uint256 collateralAmount, uint256 price) 
        internal 
        pure 
        returns (uint256) 
    {
        // Use OpenZeppelin's Math library for safe operations
        return Math.mulDiv(collateralAmount, price, 1e8);
    }

    /**
     * @dev Deposit USDC to earn interest
     */
    function deposit(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        validAmount(amount)
    {
        if (amount > type(uint128).max) revert InvalidAmount();

        // Update global interest
        _updateGlobalState();

        // Effects first (CEI pattern)
        lenderBalances[msg.sender] += amount;
        userDeposits[msg.sender] += amount;
        totalDeposits += amount;
        lastUserAction[msg.sender] = block.number;

        // Interactions last
        if (!usdc.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev Withdraw USDC from deposits
     */
    function withdraw(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        validAmount(amount)
        flashLoanProtection(msg.sender)
    {
        if (lenderBalances[msg.sender] < amount) revert InsufficientBalance();

        // Check protocol liquidity
        uint256 availableLiquidity = usdc.balanceOf(address(this)) - totalReserves;
        if (availableLiquidity < amount) revert InsufficientLiquidity();

        _updateGlobalState();

        lenderBalances[msg.sender] -= amount;
        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;
        lastUserAction[msg.sender] = block.number;

        if (!usdc.transfer(msg.sender, amount)) {
            revert TransferFailed();
        }

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @dev Borrow USDC with MNT collateral
     */
    function borrow(uint256 amount, uint256 collateral)
        external
        nonReentrant
        updateInterest(msg.sender)
        whenNotPaused
        validAmount(amount)
        flashLoanProtection(msg.sender)
    {
        if (collateral == 0) revert InvalidAmount();
        if (amount < MIN_LOAN_AMOUNT || amount > MAX_LOAN_AMOUNT) revert InvalidAmount();
        if (loans[msg.sender].isActive) revert ActiveLoanExists();

        // Check protocol liquidity
        uint256 availableLiquidity = usdc.balanceOf(address(this)) - totalReserves;
        if (availableLiquidity < amount) revert InsufficientLiquidity();

        // Get validated price with circuit breakers
        uint256 mntPrice = getValidatedPrice();

        // Calculate collateral value safely
        uint256 collateralValueUsd18 = calculateCollateralValue(collateral, mntPrice);

        // Calculate required collateral (scale USDC to 18 decimals)
        uint256 borrowAmountUsd18 = amount * 1e12;
        uint256 requiredCollateralUsd18 = Math.mulDiv(borrowAmountUsd18, COLLATERAL_RATIO, 100);

        if (collateralValueUsd18 < requiredCollateralUsd18) {
            revert InsufficientCollateral();
        }

        // Get and validate user rate
        uint256 userRate = rateAdjuster.getUserRate(msg.sender);
        if (userRate > MAX_INTEREST_RATE) revert InterestRateTooHigh();

        // Update global state
        _updateGlobalState();

       
        loans[msg.sender] = Loan({
            amount: amount,
            collateral: collateral,
            interestAccrued: 0,
            startTime: block.timestamp,
            rate: userRate,
            lastAccrualTime: block.timestamp,
            lastActionBlock: block.number,
            isActive: true
        });

        userBorrows[msg.sender] = amount;
        totalBorrows += amount;
        lastUserAction[msg.sender] = block.number;
        lastPrice = mntPrice; 

        
        if (!usdc.transfer(msg.sender, amount)) revert TransferFailed();
        if (!collateralToken.transferFrom(msg.sender, address(this), collateral)) {
            revert TransferFailed();
        }

        emit Borrow(msg.sender, amount, collateral, userRate);
    }

    /**
     * @dev Repay loan with proper accounting
     */
    function repay(uint256 amount)
        external
        nonReentrant
        updateInterest(msg.sender)
        whenNotPaused
        validAmount(amount)
    {
        Loan storage loan = loans[msg.sender];
        if (!loan.isActive) revert NoActiveLoan();

        uint256 totalDebt = loan.amount + loan.interestAccrued;
        if (amount > totalDebt) revert InvalidAmount();

        // Update global state
        _updateGlobalState();

        uint256 remainingDebt = totalDebt - amount;
        uint256 interestPortion = Math.min(amount, loan.interestAccrued);
        uint256 reserveIncrease = Math.mulDiv(interestPortion, reserveFactor, 10000);

        // Effects first (CEI pattern)
        if (remainingDebt == 0) {
            // Full repayment
            uint256 collateralToReturn = loan.collateral;
            totalBorrows -= loan.amount;
            totalReserves += reserveIncrease;
            userBorrows[msg.sender] = 0;
            delete loans[msg.sender];

            // Interactions
            if (!usdc.transferFrom(msg.sender, address(this), amount)) {
                revert TransferFailed();
            }
            if (!collateralToken.transfer(msg.sender, collateralToReturn)) {
                revert TransferFailed();
            }
        } else {
            // Partial repayment
            loan.amount = remainingDebt;
            loan.interestAccrued = 0;
            loan.lastAccrualTime = block.timestamp;
            userBorrows[msg.sender] = remainingDebt;
            totalBorrows -= (totalDebt - remainingDebt);
            totalReserves += reserveIncrease;

            // Interactions
            if (!usdc.transferFrom(msg.sender, address(this), amount)) {
                revert TransferFailed();
            }
        }

        lastUserAction[msg.sender] = block.number;
        emit Repay(msg.sender, amount, remainingDebt);
    }

    /**
     * @dev Liquidate undercollateralized positions with proper protection
     */
    function liquidate(address borrower)
        external
        nonReentrant
        updateInterest(borrower)
        whenNotPaused
        flashLoanProtection(msg.sender)
    {
        Loan storage loan = loans[borrower];
        if (!loan.isActive) revert NoActiveLoan();

        // Flash loan protection: prevent liquidating fresh loans
        if (block.number <= loan.lastActionBlock + FLASH_LOAN_PROTECTION_BLOCKS) {
            revert FlashLoanProtection();
        }

        // Get current price with validation
        uint256 mntPrice = getValidatedPrice();
        
        // Calculate current collateral value
        uint256 collateralValueUsd18 = calculateCollateralValue(loan.collateral, mntPrice);
        
        // Calculate total debt and liquidation threshold
        uint256 totalDebt = loan.amount + loan.interestAccrued;
        uint256 totalDebtUsd18 = totalDebt * 1e12;
        uint256 liquidationThresholdUsd18 = Math.mulDiv(totalDebtUsd18, LIQUIDATION_THRESHOLD, 100);

        // Check if liquidation is allowed
        if (collateralValueUsd18 >= liquidationThresholdUsd18) {
            revert LiquidationNotAllowed();
        }

        // Calculate liquidation amounts
        LiquidationInfo memory liquidation = _calculateLiquidation(loan, mntPrice, totalDebt);

        // Update global state
        _updateGlobalState();

        // Effects first (CEI pattern)
        loan.collateral -= liquidation.collateralToLiquidate;
        totalReserves += liquidation.protocolFee;

        if (liquidation.debtToRepay >= totalDebt) {
            // Full liquidation
            totalBorrows -= loan.amount;
            userBorrows[borrower] = 0;

            // Return remaining collateral to borrower if any
            uint256 remainingCollateral = loan.collateral;
            delete loans[borrower];

            // Interactions
            if (!usdc.transferFrom(msg.sender, address(this), liquidation.debtToRepay)) {
                revert TransferFailed();
            }
            if (!collateralToken.transfer(msg.sender, liquidation.collateralToLiquidate)) {
                revert TransferFailed();
            }
            if (remainingCollateral > 0) {
                if (!collateralToken.transfer(borrower, remainingCollateral)) {
                    revert TransferFailed();
                }
            }
        } else {
            // Partial liquidation
            loan.amount = totalDebt - liquidation.debtToRepay;
            loan.interestAccrued = 0;
            loan.lastAccrualTime = block.timestamp;
            loan.lastActionBlock = block.number;
            totalBorrows -= liquidation.debtToRepay;
            userBorrows[borrower] = loan.amount;

            // Interactions
            if (!usdc.transferFrom(msg.sender, address(this), liquidation.debtToRepay)) {
                revert TransferFailed();
            }
            if (!collateralToken.transfer(msg.sender, liquidation.collateralToLiquidate)) {
                revert TransferFailed();
            }
        }

        lastUserAction[msg.sender] = block.number;
        lastPrice = mntPrice; // Update last price

        emit Liquidate(
            borrower,
            msg.sender,
            liquidation.collateralToLiquidate,
            liquidation.debtToRepay,
            liquidation.liquidatorReward,
            liquidation.protocolFee
        );
    }

    /**
     * @dev Calculate liquidation amounts with safety checks
     */
    function _calculateLiquidation(Loan storage loan, uint256 mntPrice, uint256 totalDebt)
        internal
        view
        returns (LiquidationInfo memory)
    {
        // Calculate maximum liquidatable debt (50% max for partial liquidation)
        uint256 maxLiquidatableDebt = Math.mulDiv(totalDebt, MAX_LIQUIDATION_RATIO, 100);
        if (maxLiquidatableDebt == 0) {
            maxLiquidatableDebt = totalDebt;
        }

        // Calculate collateral needed to cover debt
        uint256 debtValueUsd18 = maxLiquidatableDebt * 1e12;
        uint256 collateralNeeded = Math.mulDiv(debtValueUsd18, 1e8, mntPrice);

        // Add liquidation penalty (liquidator gets extra collateral)
        uint256 penaltyCollateral = Math.mulDiv(collateralNeeded, LIQUIDATION_PENALTY, 100);
        uint256 totalCollateralToLiquidate = collateralNeeded + penaltyCollateral;

        // Protocol fee (small portion of penalty)
        uint256 protocolFee = Math.mulDiv(penaltyCollateral, reserveFactor, 10000);
        uint256 liquidatorReward = penaltyCollateral - protocolFee;

        // Don't liquidate more collateral than available
        if (totalCollateralToLiquidate > loan.collateral) {
            totalCollateralToLiquidate = loan.collateral;

            // Recalculate debt to repay based on available collateral
            uint256 collateralValueUsd18 = calculateCollateralValue(loan.collateral, mntPrice);
            uint256 debtToCoverUsd18 = Math.mulDiv(collateralValueUsd18, 100, 100 + LIQUIDATION_PENALTY);
            maxLiquidatableDebt = debtToCoverUsd18 / 1e12;

            if (maxLiquidatableDebt > totalDebt) {
                maxLiquidatableDebt = totalDebt;
            }

            // Recalculate fees
            penaltyCollateral = totalCollateralToLiquidate - Math.mulDiv(totalCollateralToLiquidate, 100, 100 + LIQUIDATION_PENALTY);
            protocolFee = Math.mulDiv(penaltyCollateral, reserveFactor, 10000);
            liquidatorReward = penaltyCollateral - protocolFee;
        }

        return LiquidationInfo({
            collateralToLiquidate: totalCollateralToLiquidate,
            debtToRepay: maxLiquidatableDebt,
            liquidatorReward: liquidatorReward,
            protocolFee: protocolFee
        });
    }

    /**
     * @dev Accrue interest with safety bounds
     */
    function _accrueInterest(address user) internal {
        Loan storage loan = loans[user];
        if (!loan.isActive) return;

        uint256 timeElapsed = block.timestamp - loan.lastAccrualTime;
        if (timeElapsed == 0) return;

        // Cap time elapsed to prevent manipulation
        timeElapsed = Math.min(timeElapsed, 30 days);

        // Safe interest calculation
        uint256 interest = Math.mulDiv(
            loan.amount * loan.rate * timeElapsed,
            1,
            SECONDS_PER_YEAR * 10000
        );

        // Cap total interest to prevent unbounded growth (200% of principal max)
        uint256 maxTotalInterest = loan.amount * 2;
        if (loan.interestAccrued + interest > maxTotalInterest) {
            interest = maxTotalInterest - loan.interestAccrued;
        }

        if (interest > 0) {
            loan.interestAccrued += interest;
            emit InterestAccrued(user, interest);
        }

        loan.lastAccrualTime = block.timestamp;
    }

    /**
     * @dev Update global protocol state
     */
    function _updateGlobalState() internal {
        lastUpdateTime = block.timestamp;
        
        // Check protocol health
        ProtocolHealth memory health = getProtocolHealth();
        emit ProtocolHealthCheck(health.isHealthy, health.utilizationRate);
    }

    // ============ TIMELOCK GOVERNANCE FUNCTIONS ============

    function scheduleSetReserveFactor(uint256 newReserveFactor) external onlyOwner {
        require(newReserveFactor <= 2000, "Reserve factor too high");
        
        bytes32 operation = keccak256(abi.encode("setReserveFactor", newReserveFactor));
        timelockScheduled[operation] = block.timestamp + TIMELOCK_DELAY;
        
        emit TimelockScheduled(operation, block.timestamp + TIMELOCK_DELAY);
    }

    function executeSetReserveFactor(uint256 newReserveFactor) external onlyOwner {
        bytes32 operation = keccak256(abi.encode("setReserveFactor", newReserveFactor));
        
        if (timelockScheduled[operation] == 0 || block.timestamp < timelockScheduled[operation]) {
            revert TimelockNotReady();
        }

        uint256 oldFactor = reserveFactor;
        reserveFactor = newReserveFactor;
        delete timelockScheduled[operation];

        emit ReserveFactorUpdated(oldFactor, newReserveFactor);
        emit TimelockExecuted(operation);
    }

    function scheduleSetChainlinkFeed(address newFeed) external onlyOwner {
        if (newFeed == address(0)) revert InvalidAddress();
        
        // Validate the feed works
        AggregatorV3Interface testFeed = AggregatorV3Interface(newFeed);
        (, int256 price, , ,) = testFeed.latestRoundData();
        if (price <= 0) revert InvalidPrice();
        
        bytes32 operation = keccak256(abi.encode("setChainlinkFeed", newFeed));
        timelockScheduled[operation] = block.timestamp + TIMELOCK_DELAY;
        
        emit TimelockScheduled(operation, block.timestamp + TIMELOCK_DELAY);
    }

    function executeSetChainlinkFeed(address newFeed) external onlyOwner {
        bytes32 operation = keccak256(abi.encode("setChainlinkFeed", newFeed));
        
        if (timelockScheduled[operation] == 0 || block.timestamp < timelockScheduled[operation]) {
            revert TimelockNotReady();
        }

        address oldFeed = address(chainlinkFeed);
        chainlinkFeed = AggregatorV3Interface(newFeed);
        delete timelockScheduled[operation];

        emit ChainlinkFeedUpdated(oldFeed, newFeed);
        emit TimelockExecuted(operation);
    }

    // ============ EMERGENCY FUNCTIONS ============

    function pause() external onlyOwner {
        _pause();
        emit EmergencyAction("pause", msg.sender, 0);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit EmergencyAction("unpause", msg.sender, 0);
    }

    function toggleFlashLoanProtection() external onlyOwner {
        flashLoanProtectionEnabled = !flashLoanProtectionEnabled;
        emit EmergencyAction("toggleFlashLoanProtection", msg.sender, flashLoanProtectionEnabled ? 1 : 0);
    }

    function emergencyWithdrawReserves(uint256 amount) external onlyOwner {
        require(amount <= totalReserves, "Insufficient reserves");
        
        totalReserves -= amount;
        
        if (!usdc.transfer(owner(), amount)) revert TransferFailed();
        emit EmergencyAction("withdrawReserves", msg.sender, amount);
    }

    function emergencyWithdrawToken(address token, uint256 amount) external onlyOwner {
        require(token != address(usdc) && token != address(collateralToken), "Cannot withdraw main tokens");
        
        if (!IERC20(token).transfer(owner(), amount)) revert TransferFailed();
        emit EmergencyAction("withdrawToken", token, amount);
    }

    // ============ VIEW FUNCTIONS ============

    function getLoanInfo(address user) external view returns (Loan memory) {
        return loans[user];
    }

    function getTotalDebt(address user) external view returns (uint256) {
        Loan storage loan = loans[user];
        if (!loan.isActive) return 0;

        uint256 timeElapsed = Math.min(block.timestamp - loan.lastAccrualTime, 30 days);
        uint256 interest = Math.mulDiv(loan.amount * loan.rate * timeElapsed, 1, SECONDS_PER_YEAR * 10000);
        
        uint256 maxTotalInterest = loan.amount * 2;
        if (loan.interestAccrued + interest > maxTotalInterest) {
            interest = maxTotalInterest - loan.interestAccrued;
        }

        return loan.amount + loan.interestAccrued + interest;
    }

    function getCollateralRatio(address user) external view returns (uint256) {
        Loan storage loan = loans[user];
        if (!loan.isActive) return 0;

        try this.getValidatedPrice() returns (uint256 price) {
            uint256 collateralValue = calculateCollateralValue(loan.collateral, price);
            uint256 totalDebt = this.getTotalDebt(user);
            uint256 totalDebtUsd18 = totalDebt * 1e12;

            if (totalDebtUsd18 == 0) return type(uint256).max;
            return Math.mulDiv(collateralValue, 100, totalDebtUsd18);
        } catch {
            return 0;
        }
    }

    function getUtilizationRate() external view returns (uint256) {
        if (totalDeposits == 0) return 0;
        return Math.mulDiv(totalBorrows, 10000, totalDeposits);
    }

    function getProtocolHealth() public view returns (ProtocolHealth memory) {
        uint256 availableLiquidity = totalDeposits > totalBorrows ? totalDeposits - totalBorrows : 0;
        uint256 utilizationRate = totalDeposits > 0 ? Math.mulDiv(totalBorrows, 10000, totalDeposits) : 0;
        
        bool isHealthy = true;
        
        // Health checks
        if (utilizationRate > 9000) isHealthy = false; // >90% utilization
        if (totalReserves < Math.mulDiv(totalBorrows, 100, 10000)) isHealthy = false; // <1% reserves
        
        try this.getValidatedPrice() returns (uint256 currentPrice) {
            return ProtocolHealth({
                totalDepositsAmount: totalDeposits,
                totalBorrowsAmount: totalBorrows,
                totalReservesAmount: totalReserves,
                utilizationRate: utilizationRate,
                availableLiquidity: availableLiquidity,
                currentPrice: 0,
                isHealthy: false
            });
        }
    }

    function canLiquidate(address user) external view returns (bool, uint256 currentRatio, uint256 liquidationRatio) {
        Loan storage loan = loans[user];
        if (!loan.isActive) return (false, 0, LIQUIDATION_THRESHOLD);

        currentRatio = this.getCollateralRatio(user);
        liquidationRatio = LIQUIDATION_THRESHOLD;
        
        bool canLiq = currentRatio < liquidationRatio && currentRatio > 0;
        return (canLiq, currentRatio, liquidationRatio);
    }

    function calculateRequiredCollateral(uint256 borrowAmount) external view returns (uint256) {
        try this.getValidatedPrice() returns (uint256 price) {
            uint256 borrowAmountUsd18 = borrowAmount * 1e12;
            uint256 requiredCollateralUsd18 = Math.mulDiv(borrowAmountUsd18, COLLATERAL_RATIO, 100);
            return Math.mulDiv(requiredCollateralUsd18, 1e8, price);
        } catch {
            return 0;
        }
    }

    function calculateMaxBorrow(uint256 collateralAmount) external view returns (uint256) {
        try this.getValidatedPrice() returns (uint256 price) {
            uint256 collateralValueUsd18 = calculateCollateralValue(collateralAmount, price);
            uint256 maxBorrowUsd18 = Math.mulDiv(collateralValueUsd18, 100, COLLATERAL_RATIO);
            return maxBorrowUsd18 / 1e12;
        } catch {
            return 0;
        }
    }

    function getLiquidationInfo(address user) external view returns (LiquidationInfo memory) {
        Loan storage loan = loans[user];
        if (!loan.isActive) {
            return LiquidationInfo(0, 0, 0, 0);
        }

        try this.getValidatedPrice() returns (uint256 price) {
            uint256 totalDebt = this.getTotalDebt(user);
            return _calculateLiquidation(loan, price, totalDebt);
        } catch {
            return LiquidationInfo(0, 0, 0, 0);
        }
    }

    function getTimelockStatus(string memory action, uint256 param) external view returns (uint256 executeTime, bool ready) {
        bytes32 operation = keccak256(abi.encode(action, param));
        executeTime = timelockScheduled[operation];
        ready = executeTime > 0 && block.timestamp >= executeTime;
    }

    function getTimelockStatusAddress(string memory action, address param) external view returns (uint256 executeTime, bool ready) {
        bytes32 operation = keccak256(abi.encode(action, param));
        executeTime = timelockScheduled[operation];
        ready = executeTime > 0 && block.timestamp >= executeTime;
    }

    // ============ LENDING RATE FUNCTIONS ============

    function getCurrentLendingRate() external view returns (uint256) {
        uint256 utilizationRate = this.getUtilizationRate();
        
        // Simple interest rate model: base rate + utilization factor
        uint256 baseRate = 200; // 2% base rate
        uint256 multiplier = Math.mulDiv(utilizationRate, 800, 10000); // Up to 8% additional
        
        return baseRate + multiplier;
    }

    function getSupplyRate() external view returns (uint256) {
        uint256 borrowRate = this.getCurrentLendingRate();
        uint256 utilizationRate = this.getUtilizationRate();
        
        // Supply rate = borrow rate * utilization rate * (1 - reserve factor)
        uint256 rateToSuppliers = Math.mulDiv(borrowRate * utilizationRate, 10000 - reserveFactor, 10000 * 10000);
        return rateToSuppliers;
    }

    // ============ BATCH OPERATIONS ============

    function batchLiquidate(address[] calldata users) external nonReentrant whenNotPaused {
        require(users.length <= 10, "Too many users"); // Gas limit protection
        
        for (uint256 i = 0; i < users.length; i++) {
            try this.liquidate(users[i]) {
                // Liquidation succeeded
            } catch {
                // Skip failed liquidations to prevent entire batch from failing
                continue;
            }
        }
    }

    // ============ MIGRATION FUNCTIONS ============

    function migrateLoan(address user, address newContract) external onlyOwner whenPaused {
        Loan storage loan = loans[user];
        require(loan.isActive, "No active loan");
        require(newContract != address(0), "Invalid contract");
        
        // This is for emergency migration only
        uint256 collateralAmount = loan.collateral;
        delete loans[user];
        userBorrows[user] = 0;
        totalBorrows -= loan.amount;
        
        if (!collateralToken.transfer(newContract, collateralAmount)) {
            revert TransferFailed();
        }
        
        emit EmergencyAction("migrateLoan", user, collateralAmount);
    }

    // ============ RECEIVE/FALLBACK ============

    // Prevent accidental ETH deposits
    receive() external payable {
        revert("ETH not accepted");
    }

    fallback() external payable {
        revert("Function not found");
    }
