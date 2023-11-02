// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EscrowPayment} from "./EscrowPayment.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Escrow Payment System Factory
 * @author Vermont Phil Paguiligan (Decrow IT Solutions)
 * 
 * @notice This contract is made to produce Escrow Payment System Contracts which is
 * initiated by the seller who also decides what the product price is, the type of
 * cryptocurrency they want to accept, and should input also the return shipping fee
 * to be payed to courier when under some circumstances, is required to return the product
 * to the seller.
 * 
 */
contract EscrowFactory is Ownable {
    error EscrowFactory__NotEOA();
    error EscrowFactory__TransferFromFailed();

    uint256 private s_inconvenienceThreshold = 50;
    address[] private s_supportedTokens;
    address[] private s_escrowList;

    event EscrowPaymentCreated(
        address indexed escrow,
        address indexed creator,
        address indexed selectedToken,
        uint256 price
    );

    constructor(address[] memory supportedTokens) Ownable(msg.sender) {
        s_supportedTokens = supportedTokens;
    }

    /**
     * @param price the decided price of the seller
     * @param index the index or position of the token accepted by seller in an array of supported tokens
     * @param returnShippingFee payment to the courier when required to return the product
     * 
     * @notice this function can only be called by EOA and not by another smart contract
     * 
     */
    function createEscrow(uint256 price, uint8 index, uint256 returnShippingFee) external returns (address) {
        if (msg.sender != tx.origin) {
            revert EscrowFactory__NotEOA();
        }

        address selectedToken = s_supportedTokens[index];
        EscrowPayment escrow = new EscrowPayment(price, selectedToken, returnShippingFee, s_inconvenienceThreshold);
        s_escrowList.push(address(escrow));

        emit EscrowPaymentCreated(address(escrow), msg.sender, selectedToken, price);
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
