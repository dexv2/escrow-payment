// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EscrowPayment {
    /////////////////
    // Errors      //
    /////////////////
    error EscrowPayment__NotABuyer();
    error EscrowPayment__NotASeller();
    error EscrowPayment__NotADeliveryDriver();
    error EscrowPayment__TransferFromFailed();
    error EscrowPayment__BuyerAlreadyDeposited();
    error EscrowPayment__SellerAlreadyDeposited();
    error EscrowPayment__DeliveryDriverAlreadyDeposited();
    error EscrowPayment__IncompleteDeposits();

    ////////////////
    // Enums      //
    ////////////////
    enum DepositorType {BUYER, SELLER, DELIVERY_DRIVER};

    //////////////////
    // Structs      //
    //////////////////
    Struct Depositors {
        address buyer;
        address seller;
        address deliveryDriver;
    }

    //////////////////////////
    // State Variables      //
    //////////////////////////
    address private s_tokenSelected;
    uint256 private s_price;
    uint8 private s_depositorsCount;
    Depositors private s_depositors;
    mapping (address depositor => uint256 amountWithdrawable) private s_amountWithdrwable;

    ////////////////////
    // Functions      //
    ////////////////////

    constructor(uint256 price, address tokenSelected, DepositorType depositorType) {
        s_price = price;
        s_tokenSelected = tokenSelected;

        deposit(depositorType);
    }

    ////////////////////
    // Modifiers      //
    ////////////////////

    modifier onlyBuyer() {
        if (msg.sender != s_depositors.buyer) {
            revert EscrowPayment__NotABuyer();
        }
        _;
    }

    modifier onlySeller() {
        if (msg.sender != s_depositors.seller) {
            revert EscrowPayment__NotASeller();
        }
        _;
    }

    modifier onlyDeliveryDriver() {
        if (msg.sender != s_depositors.deliveryDriver) {
            revert EscrowPayment__NotADeliveryDriver();
        }
        _;
    }

    /////////////////////////////
    // External Functions      //
    /////////////////////////////

    function deposit(DepositorType depositorType) public {
        if (depositorType == DepositorType.BUYER) {
            _depositAsBuyer();
        }
        else if (depositorType == DepositorType.SELLER) {
            _depositAsSeller();
        }
        else {
            _depositAsDeliveryDriver();
        }

        bool success = IERC20(tokenSelected).transferFrom(msg.sender, address(this), price);
        if (!success) {
            revert EscrowPayment__TransferFromFailed();
        }
    }

    function withdraw() external {}

    function receiveProduct() external onlyBuyer {
        if (s_depositorsCount > 3) {
            revert EscrowPayment__IncompleteDeposits();
        }
    }

    function cancel() external onlyBuyer {}

    function confirmDispute() external onlyDeliveryDriver {}

    function declineDispute() external onlyDeliveryDriver {}

    function receiveReturnedProduct() external onlySeller {}

    ////////////////////////////
    // Private Functions      //
    ////////////////////////////

    function _depositAsBuyer() private {
        if (s_depositors.buyer != address(0)) {
            revert EscrowPayment__BuyerAlreadyDeposited();
        }
        s_depositors.buyer = msg.sender;
        s_depositorsCount++;
    }

    function _depositAsSeller() private {
        if (s_depositors.seller != address(0)) {
            revert EscrowPayment__SellerAlreadyDeposited();
        }
        s_depositors.seller = msg.sender;
        s_depositorsCount++;
    }

    function _depositAsDeliveryDriver() private {
        if (s_depositors.deliveryDriver != address(0)) {
            revert EscrowPayment__DeliveryDriverAlreadyDeposited();
        }
        s_depositors.deliveryDriver = msg.sender;
        s_depositorsCount++;
    }

    //////////////////////////////////
    // External View Functions      //
    //////////////////////////////////

    function getDepositors() external view returns (Depositors) {
        return s_depositors;
    }
}
