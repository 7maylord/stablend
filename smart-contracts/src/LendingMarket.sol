// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RateAdjuster.sol";

contract LendingMarket is ReentrancyGuard, Ownable {
    IERC20 public stablecoin; // e.g., USDC
    IERC20 public collateralToken; // e.g., MNT
    RateAdjuster public rateAdjuster;
    mapping(address => uint256) public lenderBalances;
    mapping(address => Loan) public loans;
    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateralization
    
    struct Loan {
        uint256 amount;
        uint256 collateral;
        uint256 interestAccrued;
        uint256 lastUpdated;
        uint256 interestRate; // Basis points, user-specific
    }
    
    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount, uint256 collateral);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed user, uint256 amount);
    
    constructor(address _stablecoin, address _collateralToken, address _rateAdjuster) Ownable(msg.sender) {
        stablecoin = IERC20(_stablecoin);
        collateralToken = IERC20(_collateralToken);
        rateAdjuster = RateAdjuster(_rateAdjuster);
    }
    
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        stablecoin.transferFrom(msg.sender, address(this), amount);
        lenderBalances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
    
    function borrow(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        uint256 collateralNeeded = (amount * COLLATERAL_RATIO) / 100;
        require(collateralToken.balanceOf(msg.sender) >= collateralNeeded, "Insufficient collateral");
        
        uint256 userRate = rateAdjuster.getUserRate(msg.sender);
        collateralToken.transferFrom(msg.sender, address(this), collateralNeeded);
        loans[msg.sender] = Loan({
            amount: amount,
            collateral: collateralNeeded,
            interestAccrued: 0,
            lastUpdated: block.timestamp,
            interestRate: userRate
        });
        stablecoin.transfer(msg.sender, amount);
        emit Borrow(msg.sender, amount, collateralNeeded);
    }
    
    function repay(uint256 amount) external nonReentrant {
        Loan storage loan = loans[msg.sender];
        require(loan.amount > 0, "No loan");
        require(amount <= loan.amount + loan.interestAccrued, "Invalid amount");
        
        updateInterest(msg.sender);
        stablecoin.transferFrom(msg.sender, address(this), amount);
        uint256 interestPaid = amount > loan.interestAccrued ? loan.interestAccrued : amount;
        uint256 principalPaid = amount - interestPaid;
        
        loan.interestAccrued -= interestPaid;
        loan.amount -= principalPaid;
        if (loan.amount == 0) {
            collateralToken.transfer(msg.sender, loan.collateral);
            delete loans[msg.sender];
        }
        emit Repay(msg.sender, amount);
    }
    
    function liquidate(address user) external nonReentrant {
        Loan storage loan = loans[user];
        require(loan.amount > 0, "No loan");
        // Simplified: Assume external oracle checks collateral value
        require(loan.collateral < (loan.amount * COLLATERAL_RATIO) / 100, "Not undercollateralized");
        
        uint256 amount = loan.amount + loan.interestAccrued;
        delete loans[user];
        emit Liquidate(user, amount);
    }
    
    function updateInterest(address user) internal {
        Loan storage loan = loans[user];
        if (loan.amount > 0) {
            uint256 timeElapsed = block.timestamp - loan.lastUpdated;
            uint256 interest = (loan.amount * loan.interestRate * timeElapsed) / (365 days * 10000);
            loan.interestAccrued += interest;
            loan.lastUpdated = block.timestamp;
        }
    }
}