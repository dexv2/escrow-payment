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
    address public UNAUTHORIZED = makeAddr("unauthorized");
    uint256 private constant INITIAL_CREDIT = 10000e18;
    uint256 private constant PRICE = 1000e18;
    uint256 private constant RETURN_SHIPPING_FEE = 180e18;
    uint256 private constant MIN_WAITING_TIME = 10800;

    function setUp() public {
        DeployFactory deployer = new DeployFactory();
        (factory, php) = deployer.run();

        _topUpPeso();
        _createEscrow();
    }

    function _topUpPeso() private {
        vm.startPrank(factory.owner());
        factory.topUpPeso(SELLER, INITIAL_CREDIT);
        factory.topUpPeso(BUYER, INITIAL_CREDIT);
        factory.topUpPeso(COURIER, INITIAL_CREDIT);
        vm.stopPrank();
    }

    function _depositAsSeller() private {
        vm.startPrank(SELLER, SELLER);
        php.approve(address(escrow), INITIAL_CREDIT);
        escrow.deposit(EscrowPayment.DepositorType.SELLER);
        vm.stopPrank();
    }

    function _depositAsBuyer() private {
        vm.startPrank(BUYER, BUYER);
        php.approve(address(escrow), INITIAL_CREDIT);
        escrow.deposit(EscrowPayment.DepositorType.BUYER);
        vm.stopPrank();
    }

    function _depositAsCourier() private {
        vm.startPrank(COURIER, COURIER);
        php.approve(address(escrow), INITIAL_CREDIT);
        escrow.deposit(EscrowPayment.DepositorType.COURIER);
        vm.stopPrank();
    }

    function _depositAll() private {
        _depositAsSeller();
        _depositAsBuyer();
        _depositAsCourier();
    }

    function _createEscrow() private {
        vm.prank(SELLER, SELLER);
        escrow = EscrowPayment(
            factory.createEscrow(PRICE, RETURN_SHIPPING_FEE)
        );
    }

    function testExactPriceDeductedToSellerOnDeposit() public {
        uint256 startingSellerBal = php.balanceOf(SELLER);
        _depositAsSeller();
        uint256 endingSellerBal = php.balanceOf(SELLER);

        assertEq(endingSellerBal, startingSellerBal - PRICE);
    }

    function testExactPriceDeductedToBuyerOnDeposit() public {
        uint256 startingBuyerBal = php.balanceOf(BUYER);
        _depositAsBuyer();
        uint256 endingBuyerBal = php.balanceOf(BUYER);

        assertEq(endingBuyerBal, startingBuyerBal - PRICE);
    }

    function testExactPriceDeductedToCourierOnDeposit() public {
        uint256 startingCourierBal = php.balanceOf(COURIER);
        _depositAsCourier();
        uint256 endingCourierBal = php.balanceOf(COURIER);

        assertEq(endingCourierBal, startingCourierBal - PRICE);
    }

    function testEscrowBalanceEqualsTotalDeposits() public {
        _depositAll();
        uint256 escrowBal = php.balanceOf(address(escrow));

        assertEq(escrowBal, PRICE * 3);
    }

    function testAccurateDepositorCount() public {
        uint8 count0 = escrow.getDepositorsCount();
        _depositAsSeller();
        uint8 count1 = escrow.getDepositorsCount();
        _depositAsBuyer();
        uint8 count2 = escrow.getDepositorsCount();
        _depositAsCourier();
        uint8 count3 = escrow.getDepositorsCount();

        assertEq(count0, 0);
        assertEq(count1, 1);
        assertEq(count2, 2);
        assertEq(count3, 3);
    }

    function testSetAccurateSellerInfoOnDeposit() public {
        _depositAsSeller();

        (
            EscrowPayment.DepositorType depositorType, 
            uint256 amountDeposit
        ) = escrow.getDepositorInfo(SELLER);

        assertEq(amountDeposit, PRICE);
        assertEq(uint256(depositorType), uint256(EscrowPayment.DepositorType.SELLER));
        assertEq(escrow.getSeller(), SELLER);
    }

    function testSetAccurateBuyerInfoOnDeposit() public {
        _depositAsBuyer();

        (
            EscrowPayment.DepositorType depositorType, 
            uint256 amountDeposit
        ) = escrow.getDepositorInfo(BUYER);

        assertEq(amountDeposit, PRICE);
        assertEq(uint256(depositorType), uint256(EscrowPayment.DepositorType.BUYER));
        assertEq(escrow.getBuyer(), BUYER);
    }

    function testSetAccurateCourierInfoOnDeposit() public {
        _depositAsCourier();

        (
            EscrowPayment.DepositorType depositorType, 
            uint256 amountDeposit
        ) = escrow.getDepositorInfo(COURIER);

        assertEq(amountDeposit, PRICE);
        assertEq(uint256(depositorType), uint256(EscrowPayment.DepositorType.COURIER));
        assertEq(escrow.getCourier(), COURIER);
    }

    function testRevertsIfDepositorIsNotEOA() public {
        vm.startPrank(SELLER);
        php.approve(address(escrow), INITIAL_CREDIT);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowPayment.EscrowPayment__NotEOA.selector
            )
        );
        escrow.deposit(EscrowPayment.DepositorType.SELLER);
        vm.stopPrank();
    }

    function testRevertsIfDepositedTwice() public {
        _depositAsSeller();
        vm.startPrank(SELLER, SELLER);
        php.approve(address(escrow), INITIAL_CREDIT);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowPayment.EscrowPayment__AlreadyDeposited.selector,
                EscrowPayment.DepositorType.SELLER,
                SELLER
            )
        );
        escrow.deposit(EscrowPayment.DepositorType.SELLER);
        vm.stopPrank();
    }

    function testCannotWithdrawWhenTransactionIsOngoing() public {
        _depositAsSeller();
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowPayment.EscrowPayment__TransactionStillOngoing.selector
            )
        );
        vm.prank(SELLER, SELLER);
        escrow.withdraw();
    }

    function testCannotEmergencyWithdrawWhenAllDepositorsDeposited() public {
        _depositAll();

        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowPayment.EscrowPayment__NotAllowedWhenAllHaveDeposited.selector
            )
        );
        vm.prank(SELLER, SELLER);
        escrow.emergencyWithdraw();
    }

    function testCannotEmergencyWithdrawWhenNotIdle() public {
        _depositAsSeller();

        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowPayment.EscrowPayment__NotYetIdle.selector
            )
        );
        vm.prank(SELLER, SELLER);
        escrow.emergencyWithdraw();
    }

    function _emergencyWithdraw() private {
        vm.warp(block.timestamp + MIN_WAITING_TIME + 1);
        vm.prank(SELLER, SELLER);
        escrow.emergencyWithdraw();
    }

    function testUpdateDepositorsCountAfterEmergencyWithdraw() public {
        _depositAsSeller();
        uint8 depositorsCountBefore = escrow.getDepositorsCount();
        _emergencyWithdraw();
        uint8 depositorsCountAfter = escrow.getDepositorsCount();

        assertEq(depositorsCountAfter, depositorsCountBefore - 1);
    }

    function testUpdateDepositorAddressAfterEmergencyWithdraw() public {
        _depositAsSeller();
        address sellerAddressBefore = escrow.getSeller();
        _emergencyWithdraw();
        address sellerAddressAfter = escrow.getSeller();

        assertEq(sellerAddressBefore, SELLER);
        assertEq(sellerAddressAfter, address(0));
    }

    function testUpdateDepositorTypeAfterEmergencyWithdraw() public {
        _depositAsSeller();
        (EscrowPayment.DepositorType typeBefore, ) = escrow.getDepositorInfo(SELLER);
        _emergencyWithdraw();
        (EscrowPayment.DepositorType typeAfter, ) = escrow.getDepositorInfo(SELLER);

        assertEq(uint8(typeBefore), uint8(EscrowPayment.DepositorType.SELLER));
        assertEq(uint8(typeAfter), uint8(EscrowPayment.DepositorType.NONE));
    }

    function testUpdateAmountWithdrawableAfterEmergencyWithdraw() public {
        _depositAsSeller();
        (, uint256 withdrawableBefore) = escrow.getDepositorInfo(SELLER);
        _emergencyWithdraw();
        (, uint256 withdrawableAfter) = escrow.getDepositorInfo(SELLER);

        assertEq(withdrawableBefore, PRICE);
        assertEq(withdrawableAfter, 0);
    }

    function testRevertsIfIncompleteDepositsOnReceivingProduct() public {
        _depositAsSeller();
        _depositAsBuyer();

        vm.prank(BUYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowPayment.EscrowPayment__IncompleteDeposits.selector
            )
        );
        escrow.receiveProduct();
    }

    function testRevertsWithOnlyBuyerModifierOnReceiveProduct() public {
        _depositAll();

        vm.prank(COURIER);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowPayment.EscrowPayment__NotABuyer.selector
            )
        );
        escrow.receiveProduct();
    }

    function testPaymentTransferedToSellerUponReceivingProduct() public {
        _depositAll();
        uint256 buyerDepositBefore = escrow.getAmountWithdrawable(BUYER);
        uint256 sellerDepositBefore = escrow.getAmountWithdrawable(SELLER);

        vm.prank(BUYER);
        escrow.receiveProduct();
        uint256 selerDepositAfter = escrow.getAmountWithdrawable(SELLER);

        assertEq(selerDepositAfter, sellerDepositBefore + buyerDepositBefore);
    }
}
