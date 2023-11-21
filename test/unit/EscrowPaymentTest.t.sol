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
    address public COURIER = makeAddr("courier");
    uint256 private constant CREDIT = 10000e18;

    function setUp() public {
        DeployFactory deployer = new DeployFactory();
        (factory, php) = deployer.run();

        vm.startPrank(factory.owner());
        factory.topUpPeso(SELLER, CREDIT);
        factory.topUpPeso(BUYER, CREDIT);
        factory.topUpPeso(COURIER, CREDIT);
        vm.stopPrank();
    }

    function _createEscrow(uint256 price, uint256 returnShippingFee) private returns (address) {
        vm.prank(SELLER, SELLER);
        return factory.createEscrow(price, returnShippingFee);
    }

    function testCanCreateEscrow() public {
        uint256 price = 1000e18;
        uint256 returnDeliveryFee = 180e18;

        EscrowPayment(_createEscrow(price, returnDeliveryFee));
    }
}
