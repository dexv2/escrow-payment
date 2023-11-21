// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {EscrowPayment} from "../../src/EscrowPayment.sol";
import {EscrowFactory} from "../../src/EscrowFactory.sol";
import {PhilippinePeso} from "../../src/PhilippinePeso.sol";
import {DeployFactory} from "../../script/DeployFactory.sol";

contract EscrowPaymentTest is Test {
    EscrowFactory factory;
    EscrowPayment escrow;
    PhilippinePeso php;

    address public SELLER = makeAddr("seller");
    address public BUYER = makeAddr("buyer");
    address public Courier = makeAddr("courier");

    function setUp() public {
        DeployFactory deployer = new DeployFactory();
        
    }
}
