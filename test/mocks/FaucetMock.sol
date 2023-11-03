// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20Mock} from "./ERC20Mock.sol";

/**
 * @title STCFaucet
 * @author Vermont Phil Paguiligan
 * @notice This contract funds users to use the EscrowPayment contract as Depositor
 */
contract STCFaucet {
    error STCFaucet__FaucetHasZeroBalance();

    uint256 private constant REQUEST_AMOUNT = 1000e18;
    ERC20Mock private immutable i_stc;

    constructor(address stc) {
        i_stc = ERC20Mock(stc);
    }

    function requestSTC() public {
        if (_faucetBalanceSTC() == 0) {
            revert STCFaucet__FaucetHasZeroBalance();
        }

        if (_faucetBalanceSTC() < REQUEST_AMOUNT) {
            i_stc.transfer(msg.sender, _faucetBalanceSTC());
        }
        else {
            i_stc.transfer(msg.sender, REQUEST_AMOUNT);
        }
    }

    function _faucetBalanceSTC() private view returns (uint256) {
        return i_stc.balanceOf(address(this));
    }

    function getFaucetBalanceSTC() public view returns (uint256) {
        return _faucetBalanceSTC();
    }

    function getSTCAddress() public view returns (address) {
        return address(i_stc);
    }

    function getRequestAmount() public pure returns (uint256) {
        return REQUEST_AMOUNT;
    }
}
