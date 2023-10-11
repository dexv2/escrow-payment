// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

contract EscrowPayment {
    address private s_buyer;
    address private s_seller;
    address private s_deliveryDriver;
    mapping (address depositor => uint256 amountWithdrawable) s_amountWithdrwable;
    mapping (address depositor => uint256 amountDeposit) s_amountDeposit;

    function deposit() external {}
    function withdraw() external {}
    function receiveProduct() external {}
    function cancel() external {}
    function approveDispute() external {}
    function rejectDispute() external {}
    function receiveReturnedProduct() external {}
}
