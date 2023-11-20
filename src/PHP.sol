// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PHP is ERC20, Ownable {
    error PHP__NotZeroAddress();
    error PHP__MustBeMoreThanZero();

    constructor(address initialOwner)
        Ownable(initialOwner)
        ERC20("Philippine Peso", "PHP") {}

    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        if (to == address(0)) {
            revert PHP__NotZeroAddress();
        }
        if (amount == 0) {
            revert PHP__MustBeMoreThanZero();
        }
        _mint(to, amount);
        return true;
    }

}
