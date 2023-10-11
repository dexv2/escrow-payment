// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EscrowPayment {
    error EscrowPayment__NotABuyer();
    error EscrowPayment__NotASeller();
    error EscrowPayment__NotADeliveryDriver();
    error EscrowPayment__TransferFromFailed();
    error EscrowPayment__BuyerAlreadyDeposited();
    error EscrowPayment__SellerAlreadyDeposited();
    error EscrowPayment__DeliveryDriverAlreadyDeposited();

    enum DepositorType {BUYER, SELLER, DELIVERY_DRIVER};

    address private s_buyer;
    address private s_seller;
    address private s_deliveryDriver;
    address private s_tokenSelected;
    uint256 private s_price;
    mapping (address depositor => uint256 amountWithdrawable) s_amountWithdrwable;
    mapping (address depositor => uint256 amountDeposit) s_amountDeposit;

    constructor(uint256 price, address tokenSelected, DepositorType depositorType) {
        s_price = price;
        s_tokenSelected = tokenSelected;

        deposit(depositorType);
    }

    modifier onlyBuyer() {
        if (msg.sender != s_buyer) {
            revert EscrowPayment__NotABuyer();
        }
        _;
    }

    modifier onlySeller() {
        if (msg.sender != s_seller) {
            revert EscrowPayment__NotASeller();
        }
        _;
    }

    modifier onlyDeliveryDriver() {
        if (msg.sender != s_deliveryDriver) {
            revert EscrowPayment__NotADeliveryDriver();
        }
        _;
    }

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

    function receiveProduct() external onlyBuyer {}

    function cancel() external onlyBuyer {}

    function confirmDispute() external onlyDeliveryDriver {}

    function declineDispute() external onlyDeliveryDriver {}

    function receiveReturnedProduct() external onlySeller {}

    function _depositAsBuyer() private {
        if (s_buyer != address(0)) {
            revert EscrowPayment__BuyerAlreadyDeposited();
        }
        s_buyer = msg.sender();
    }

    function _depositAsSeller() private {
        if (s_seller != address(0)) {
            revert EscrowPayment__SellerAlreadyDeposited();
        }
        s_seller = msg.sender();
    }

    function _depositAsDeliveryDriver() private {
        if (s_deliveryDriver != address(0)) {
            revert EscrowPayment__DeliveryDriverAlreadyDeposited();
        }
        s_deliveryDriver = msg.sender();
    }
}
