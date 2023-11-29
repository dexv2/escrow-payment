// SPDX-License-Identifier: MIT
/*
 /$$$$$$$$
| $$_____/
| $$        /$$$$$$$  /$$$$$$$  /$$$$$$   /$$$$$$  /$$  /$$  /$$
| $$$$$    /$$_____/ /$$_____/ /$$__  $$ /$$__  $$| $$ | $$ | $$
| $$__/   |  $$$$$$ | $$      | $$  \__/| $$  \ $$| $$ | $$ | $$
| $$       \____  $$| $$      | $$      | $$  | $$| $$ | $$ | $$
| $$$$$$$$ /$$$$$$$/|  $$$$$$$| $$      |  $$$$$$/|  $$$$$/$$$$/
|________/|_______/  \_______/|__/       \______/  \_____/\___/

 /$$$$$$$                                                         /$$
| $$__  $$                                                       | $$
| $$  \ $$ /$$$$$$  /$$   /$$ /$$$$$$/$$$$   /$$$$$$  /$$$$$$$  /$$$$$$
| $$$$$$$/|____  $$| $$  | $$| $$_  $$_  $$ /$$__  $$| $$__  $$|_  $$_/
| $$____/  /$$$$$$$| $$  | $$| $$ \ $$ \ $$| $$$$$$$$| $$  \ $$  | $$
| $$      /$$__  $$| $$  | $$| $$ | $$ | $$| $$_____/| $$  | $$  | $$ /$$
| $$     |  $$$$$$$|  $$$$$$$| $$ | $$ | $$|  $$$$$$$| $$  | $$  |  $$$$/
|__/      \_______/ \____  $$|__/ |__/ |__/ \_______/|__/  |__/   \___/
                    /$$  | $$
                   |  $$$$$$/
                    \______/
  /$$$$$$                        /$$
 /$$__  $$                      | $$
| $$  \__/ /$$   /$$  /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$/$$$$
|  $$$$$$ | $$  | $$ /$$_____/|_  $$_/   /$$__  $$| $$_  $$_  $$
 \____  $$| $$  | $$|  $$$$$$   | $$    | $$$$$$$$| $$ \ $$ \ $$
 /$$  \ $$| $$  | $$ \____  $$  | $$ /$$| $$_____/| $$ | $$ | $$
|  $$$$$$/|  $$$$$$$ /$$$$$$$/  |  $$$$/|  $$$$$$$| $$ | $$ | $$
 \______/  \____  $$|_______/    \___/   \_______/|__/ |__/ |__/
           /$$  | $$
          |  $$$$$$/
           \______/
*/

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EscrowPayment} from "./EscrowPayment.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PhilippinePeso} from "./PhilippinePeso.sol";

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

    address private immutable i_philippinePeso;
    uint256 private s_inconvenienceThreshold;
    // address[] private s_supportedTokens;
    address[] private s_escrowList;

    event EscrowPaymentCreated(
        address indexed escrow,
        address indexed creator,
        address indexed selectedToken,
        uint256 price
    );

    constructor(
        address philippinePeso,
        uint256 inconvenienceThreshold
    ) Ownable(msg.sender) {
        i_philippinePeso = philippinePeso;
        s_inconvenienceThreshold = inconvenienceThreshold;
    }

    /**
     * @param price the decided price of the seller
     * @param returnShippingFee payment to the courier when required to return the product
     * 
     * @notice this function can only be called by EOA and not by another smart contract
     * 
     */
    function createEscrow(uint256 price, uint256 returnShippingFee) external returns (address) {
        if (msg.sender != tx.origin) {
            revert EscrowFactory__NotEOA();
        }

        EscrowPayment escrow = new EscrowPayment(price, i_philippinePeso, returnShippingFee, s_inconvenienceThreshold);
        s_escrowList.push(address(escrow));

        emit EscrowPaymentCreated(address(escrow), msg.sender, i_philippinePeso, price);
        return address(escrow);
    }

    function updateInconvenienceThreshold(uint256 newThreshold) external onlyOwner {
        s_inconvenienceThreshold = newThreshold;
    }

    function topUpPeso(address to, uint256 amount) external onlyOwner {
        PhilippinePeso(i_philippinePeso).mint(to, amount);
    }

    function getPhpAddress() external view returns (address) {
        return i_philippinePeso;
    }
}
