// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

contract EscrowPayment {
    error EscrowPayment__NotABuyer();
    error EscrowPayment__NotASeller();
    error EscrowPayment__NotADeliveryDriver();

    address private s_buyer;
    address private s_seller;
    address private s_deliveryDriver;
    mapping (address depositor => uint256 amountWithdrawable) s_amountWithdrwable;
    mapping (address depositor => uint256 amountDeposit) s_amountDeposit;

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

    function deposit() external {}
    function withdraw() external {}
    function receiveProduct() external onlyBuyer {}
    function cancel() external onlyBuyer {}
    function approveDispute() external onlyDeliveryDriver {}
    function rejectDispute() external onlyDeliveryDriver {}
    function receiveReturnedProduct() external onlySeller {}
}
