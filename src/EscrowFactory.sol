// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EscrowPayment} from "./EscrowPayment.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EscrowFactory is Ownable {
    error EscrowFactory__NotEOA();
    error EscrowFactory__TransferFromFailed();

    uint256 private s_inconvenienceThreshold = 50;
    address[] s_supportedTokens;

    constructor(address[] memory supportedTokens) Ownable(msg.sender) {
        s_supportedTokens = supportedTokens;
    }

    function initiateEscrow(uint256 price, uint8 index, uint256 shippingFee) external returns (address) {
        if (msg.sender != tx.origin) {
            revert EscrowFactory__NotEOA();
        }
        address selectedToken = s_supportedTokens[index];
        EscrowPayment escrow = new EscrowPayment(price, selectedToken, shippingFee, s_inconvenienceThreshold);

        return address(escrow);
    }

    function getSupportedTokenByIndex(uint8 index) external view returns (address) {
        address[] memory supportedTokens = s_supportedTokens;
        if (index >= supportedTokens.length) {
            return address(0);
        }
        return supportedTokens[index];
    }
}
