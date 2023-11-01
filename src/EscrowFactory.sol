// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EscrowPayment} from "./EscrowPayment.sol";

contract EscrowFactory is Ownable {
    uint256 private s_inconvenienceThreshold = 50;
    address[] s_supportedTokens;

    constructor(address[] memory supportedTokens) Ownable(msg.sender) {
        s_supportedTokens = supportedTokens;
    }

    function initiateEscrow(uint256 price) external {

    }

    function _getSupportedTokenByIndex(uint8 index) private view returns (address) {
        address[] memory supportedTokens = s_supportedTokens;
        if (index >= supportedTokens.length) {
            return address(0);
        }
        return supportedTokens[index];
    }
}
