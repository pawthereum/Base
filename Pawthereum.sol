// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";

contract Pawthereum is ERC20, ERC20Permit, Ownable {
    bool public isInitialized;
    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => bool) public isFeeExempt;
    uint256 public constant MAX_FEE = 3 * 10**16; // 3%
    uint256 public fee = 3 * 10**16; // 3%
    address public feeAddress;

    constructor(address initialOwner)
        ERC20("Pawthereum", "PAWTH")
        ERC20Permit("Pawthereum")
        Ownable(initialOwner)
    {
        feeAddress = initialOwner;
        _mint(msg.sender, 1000000000 * 10**decimals());
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(isInitialized || from == owner() || to == owner(), "Pawthereum: Contract not initialized");
        if (automatedMarketMakerPairs[from] && !isFeeExempt[to] && !isFeeExempt[from]) {
            uint256 feeAmount = (amount * fee) / 1e18;
            require(amount > feeAmount, "Pawthereum: Fee exceeds transfer amount");
            super._update(from, feeAddress, feeAmount);
            super._update(from, to, amount - feeAmount);
        } else {
            super._update(from, to, amount);
        }
    }

    function setFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_FEE, "Pawthereum: fee too high");
        fee = newFee;
    }

    function setFeeAddress(address newFeeAddress) external onlyOwner {
        feeAddress = newFeeAddress;
    }

    function setAutomatedMarketMakerPair(address ammAddress, bool isAmm) external onlyOwner {
        require(ammAddress != address(0), "Pawthereum: Invalid AMM address");
        automatedMarketMakerPairs[ammAddress] = isAmm;
    }

    function setFeeExemptionStatus(address account, bool isExempt) external onlyOwner {
        isFeeExempt[account] = isExempt;
    }

    // receive ether
    receive() external payable {}

    // withdraw ether
    function withdraw(address _withdrawTo) external onlyOwner {
        (bool success, ) = payable(_withdrawTo).call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    // withdraw stuck erc-20 tokens
    function withdrawErc20(address _token, address _withdrawTo) external onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_withdrawTo, balance);
    }

    // initalize the contract
    function initialize() external onlyOwner {
        require(!isInitialized, "Pawthereum: already initialized");
        isInitialized = true;
    }
}