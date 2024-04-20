// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Pawthereum
 * @dev Extends ERC20 token with fee on transfer and permit functionality.
 * @notice Pawthereum is a fee-on-transfer ERC20 token that also supports the ERC20 Permit extension,
 * allowing for gasless transactions. It includes features for owner management, automated market maker (AMM) pair management,
 * fee exemption for specific addresses, and adjustable fees with an upper limit.
 * @custom:security-contact contact@pawthereum.com
 */
contract Pawthereum is ERC20, ERC20Permit, ERC20Votes, Ownable {
    bool public isInitialized;
    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => bool) public isFeeExempt;
    uint256 public maxFee = 3 * 10**16; // 3%
    uint256 public fee = 3 * 10**16; // Initially set to 3%
    address public feeAddress;
    address immutable public airdropAddress;

    event FeeSet(uint256 newFee);
    event FeeAddressSet(address newFeeAddress);
    event AMMPairSet(address ammAddress, bool isAmm);
    event FeeExemptionStatusSet(address account, bool isExempt);
    event Withdraw(address withdrawTo, uint256 amount);
    event WithdrawErc20(address token, address withdrawTo, uint256 amount);
    event Initialized();

    /**
     * @dev Sets the initial owner and mints initial token supply to the deployer.
     * @param _airdropAddress The address to be used for airdrops.
     */
    constructor(address _initialOwner, address _airdropAddress)
        ERC20("Pawthereum", "PAWTH")
        ERC20Permit("Pawthereum")
        Ownable(_initialOwner)
    {
        airdropAddress = _airdropAddress;
        feeAddress = _initialOwner;
        _mint(_initialOwner, 1000000000 * 10**decimals());
    }

    /**
     * @dev Overrides the internal _update function to apply fees for transfers that are not exempted or 
     * occur through AMM pairs, if the contract is initialized.
     * @param from Address sending the tokens.
     * @param to Address receiving the tokens.
     * @param amount Number of tokens to send.
     */
    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        require(isInitialized || isAirdrop(from, to), "Pawthereum: Contract not initialized");
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
     * @dev Checks if an address is the owner or the airdrop address.
     * @param from The address to check.
     * @return Whether the address is the owner or the airdrop address.
     */
    function isAirdrop(address from, address to) public view returns (bool) {
        return to == owner() || from == owner() || from == airdropAddress;
    }

    /**
     * @dev Overrides the nonces function to return the nonces of an address.
     * @param owner The address to check the nonces for.
     * @return onces of the address.
     */
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    /**
     * @dev Allows the owner to adjust the fee rate within a preset maximum limit.
     * @param newFee The new fee percentage to be set.
     */
    function setFee(uint256 newFee) external onlyOwner {
        require(newFee <= maxFee, "Pawthereum: fee too high");
        fee = newFee;
        emit FeeSet(newFee);
    }

    /**
     * @dev Allows the owner to change the fee address.
     * @param newFeeAddress The address that will collect the fees.
     */
    function setFeeAddress(address newFeeAddress) external onlyOwner {
        feeAddress = newFeeAddress;
        emit FeeAddressSet(newFeeAddress);
    }

    /**
     * @dev Allows the owner to designate or undesignate an address as an automated market maker (AMM) pair.
     * @param ammAddress The address to be designated as an AMM pair.
     * @param isAmm Indicates whether the address is an AMM pair.
     */
    function setAutomatedMarketMakerPair(address ammAddress, bool isAmm) external onlyOwner {
        require(ammAddress != address(0), "Pawthereum: Invalid AMM address");
        automatedMarketMakerPairs[ammAddress] = isAmm;
        emit AMMPairSet(ammAddress, isAmm);
    }

    /**
     * @dev Allows the owner to exempt or unexempt an account from transfer fees.
     * @param account The account to update the fee exemption status for.
     * @param isExempt Whether the account is to be exempt from fees.
     */
    function setFeeExemptionStatus(address account, bool isExempt) external onlyOwner {
        isFeeExempt[account] = isExempt;
        emit FeeExemptionStatusSet(account, isExempt);
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
        emit Withdraw(_withdrawTo, address(this).balance);
    }

    /**
     * @dev Allows the owner to withdraw ERC-20 tokens sent to the contract by mistake.
     * @param _token The address of the ERC-20 token to withdraw.
     * @param _withdrawTo The address to receive the tokens.
     */
    function withdrawErc20(address _token, address _withdrawTo) external onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_withdrawTo, balance);
        emit WithdrawErc20(_token, _withdrawTo, balance);
    }

    /**
     * @dev Allows the owner to set the max fee. However, the new max fee must be lower than the current max fee.
    * @param _maxFee The new max fee to be set.
     */
    function setMaxFee(uint256 _maxFee) external onlyOwner {
        require(_maxFee < maxFee, "Pawthereum: new max fee must be lower than current max fee");
        maxFee = _maxFee;
    }

    /**
     * @dev Initializes the contract, allowing for transfers.
     * Can only be called once by the owner.
     */
    function initialize() external onlyOwner {
        require(!isInitialized, "Pawthereum: already initialized");
        isInitialized = true;
        emit Initialized();
    }
}
