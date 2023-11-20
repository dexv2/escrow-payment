// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PhilippinePeso is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    error PhilippinePeso__NotZeroAddress();
    error PhilippinePeso__MustBeMoreThanZero();

    constructor(address initialOwner)
        ERC20("Philippine Peso", "PHP")
        Ownable(initialOwner)
    {}

    function mint(address to, uint256 amount)
        public
        whenNotPaused 
        onlyOwner
        returns (bool) 
    {
        if (to == address(0)) {
            revert PhilippinePeso__NotZeroAddress();
        }
        if (amount == 0) {
            revert PhilippinePeso__MustBeMoreThanZero();
        }
        _mint(to, amount);
        return true;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}