// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockMNT is ERC20, Ownable {
    uint8 private _decimals = 18; // MNT has 18 decimals

    constructor() ERC20("Mock MNT", "mMNT") Ownable(msg.sender) {}

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // Mint function for testing
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Burn function
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
