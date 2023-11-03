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
    ERC20Mock private immutable i_stc1;
    ERC20Mock private immutable i_stc2;
    ERC20Mock private immutable i_stc3;

    constructor(address stc1, address stc2, address stc3) {
        i_stc1 = ERC20Mock(stc1);
        i_stc2 = ERC20Mock(stc2);
        i_stc3 = ERC20Mock(stc3);
    }

    function requestSTC1() public {
        i_stc1.transfer(msg.sender, REQUEST_AMOUNT);
    }

    function requestSTC2() public {
        i_stc2.transfer(msg.sender, REQUEST_AMOUNT);
    }

    function requestSTC3() public {
        i_stc3.transfer(msg.sender, REQUEST_AMOUNT);
    }

    function getSTC1Address() public view returns (address) {
        return address(i_stc1);
    }

    function getSTC2Address() public view returns (address) {
        return address(i_stc2);
    }

    function getSTC3Address() public view returns (address) {
        return address(i_stc3);
    }

    function getRequestAmount() public pure returns (uint256) {
        return REQUEST_AMOUNT;
    }
}
