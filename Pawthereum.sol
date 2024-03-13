// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";

/**
 * @title Pawthereum
 * @dev Extends ERC20 token with fee on transfer and permit functionality.
 * @notice Pawthereum is a fee-on-transfer ERC20 token that also supports the ERC20 Permit extension,
 * allowing for gasless transactions. It includes features for owner management, automated market maker (AMM) pair management,
 * fee exemption for specific addresses, and adjustable fees with an upper limit.
 */
contract Pawthereum is ERC20, ERC20Permit, Ownable {
    bool public isInitialized;
    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => bool) public isFeeExempt;
    uint256 public constant MAX_FEE = 3 * 10**16; // 3%
    uint256 public fee = 3 * 10**16; // Initially set to 3%
    address public feeAddress;

    /**
     * @dev Sets the initial owner and mints initial token supply to the deployer.
     * @param initialOwner Address that will be granted the contract ownership and initial fee address.
     */
    constructor(address initialOwner)
        ERC20("Pawthereum", "PAWTH")
        ERC20Permit("Pawthereum")
        Ownable(initialOwner)
    {
        feeAddress = initialOwner;
        _mint(msg.sender, 1000000000 * 10**decimals());
    }

    /**
     * @dev Overrides the internal _update function to apply fees for transfers that are not exempted or 
     * occur through AMM pairs, if the contract is initialized.
     * @param from Address sending the tokens.
     * @param to Address receiving the tokens.
     * @param amount Number of tokens to send.
     */
    function _update(address from, address to, uint256 amount) internal override {
        require(isInitialized || from == owner() || to == owner(), "Pawthereum: Contract not initialized");
        // Check if the transfer is from an AMM pair and if at least one of the parties is not fee exempt
        if (automatedMarketMakerPairs[from] && (!isFeeExempt[to] || !isFeeExempt[from])) {
            uint256 feeAmount = (amount * fee) / 1e18;
            require(amount > feeAmount, "Pawthereum: Fee exceeds transfer amount");
            super._update(from, feeAddress, feeAmount);
            super._update(from, to, amount - feeAmount);
        } else {
            super._update(from, to, amount);
        }
    }

    /**
     * @dev Allows the owner to adjust the fee rate within a preset maximum limit.
     * @param newFee The new fee percentage to be set.
     */
    function setFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_FEE, "Pawthereum: fee too high");
        fee = newFee;
    }

    /**
     * @dev Allows the owner to change the fee address.
     * @param newFeeAddress The address that will collect the fees.
     */
    function setFeeAddress(address newFeeAddress) external onlyOwner {
        feeAddress = newFeeAddress;
    }

    /**
     * @dev Allows the owner to designate or undesignate an address as an automated market maker (AMM) pair.
     * @param ammAddress The address to be designated as an AMM pair.
     * @param isAmm Indicates whether the address is an AMM pair.
     */
    function setAutomatedMarketMakerPair(address ammAddress, bool isAmm) external onlyOwner {
        require(ammAddress != address(0), "Pawthereum: Invalid AMM address");
        automatedMarketMakerPairs[ammAddress] = isAmm;
    }

    /**
     * @dev Allows the owner to exempt or unexempt an account from transfer fees.
     * @param account The account to update the fee exemption status for.
     * @param isExempt Whether the account is to be exempt from fees.
     */
    function setFeeExemptionStatus(address account, bool isExempt) external onlyOwner {
        isFeeExempt[account] = isExempt;
    }

    /**
     * @dev Allows the contract to receive Ether.
     */
    receive() external payable {}

    /**
     * @dev Allows the owner to withdraw Ether collected in the contract.
     * @param _withdrawTo The address to send the Ether to.
     */
    function withdraw(address _withdrawTo) external onlyOwner {
        (bool success, ) = payable(_withdrawTo).call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    /**
     * @dev Allows the owner to withdraw ERC-20 tokens sent to the contract by mistake.
     * @param _token The address of the ERC-20 token to withdraw.
     * @param _withdrawTo The address to receive the tokens.
     */
    function withdrawErc20(address _token, address _withdrawTo) external onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_withdrawTo, balance);
    }

    /**
     * @dev Initializes the contract, allowing for fee enforcement and AMM pair functionality.
     * Can only be called once by the owner.
     */
    function initialize() external onlyOwner {
        require(!isInitialized, "Pawthereum: already initialized");
        isInitialized = true;
    }
}
