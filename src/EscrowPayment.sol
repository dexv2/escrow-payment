// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EscrowPayment {
    /////////////////
    // Errors      //
    /////////////////
    error EscrowPayment__NotABuyer();
    error EscrowPayment__NotASeller();
    error EscrowPayment__NotACourier();
    error EscrowPayment__TransferFailed();
    error EscrowPayment__TransferFromFailed();
    error EscrowPayment__BuyerAlreadyDeposited();
    error EscrowPayment__SellerAlreadyDeposited();
    error EscrowPayment__CourierAlreadyDeposited();
    error EscrowPayment__IncompleteDeposits();
    error EscrowPayment__NoOutstandingAmountWithdrawable();
    error EscrowPayment__TransactionStillOngoing();
    error EscrowPayment__NoDisputeFiled();

    ////////////////
    // Enums      //
    ////////////////
    enum DepositorType { BUYER, SELLER, COURIER }

    //////////////////
    // Structs      //
    //////////////////
    struct Depositors {
        address buyer;
        address seller;
        address courier;
    }

    //////////////////////////
    // State Variables      //
    //////////////////////////
    uint256 private constant INCONVENIENCE_THRESHOLD = 50;
    uint256 private constant PRECISION = 100;

    IERC20 private immutable i_tokenSelected;
    uint256 private immutable i_price;
    uint256 private immutable i_shippingFee;
    uint8 private s_depositorsCount;
    bool private s_transactionCompleted;
    bool private s_buyerFiledDispute;
    Depositors private s_depositors;

    mapping (address depositor => uint256 amountWithdrawable) private s_amountWithdrawable;

    ////////////////////
    // Functions      //
    ////////////////////

    constructor(uint256 price, address tokenSelected, DepositorType depositorType, uint256 shippingFee) {
        i_price = price;
        i_shippingFee = shippingFee;
        i_tokenSelected = IERC20(tokenSelected);

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

    modifier onlyCourier() {
        if (msg.sender != s_depositors.courier) {
            revert EscrowPayment__NotACourier();
        }
        _;
    }

    modifier hasDispute() {
        if (!s_buyerFiledDispute) {
            revert EscrowPayment__NoDisputeFiled();
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
            _depositAsCourier();
        }

        s_amountWithdrawable[msg.sender] = i_price;
        bool success = i_tokenSelected.transferFrom(msg.sender, address(this), i_price);
        if (!success) {
            revert EscrowPayment__TransferFromFailed();
        }
        s_depositorsCount++;
    }

    // follows CEI
    function withdraw() external {
        uint256 amountWithdrawable = s_amountWithdrawable[msg.sender];
        if (amountWithdrawable <= 0) {
            revert EscrowPayment__NoOutstandingAmountWithdrawable();
        }
        if (!s_transactionCompleted) {
            revert EscrowPayment__TransactionStillOngoing();
        }

        s_amountWithdrawable[msg.sender] = 0;
        bool success = i_tokenSelected.transfer(msg.sender, amountWithdrawable);
        if (!success) {
            revert EscrowPayment__TransferFailed();
        }
    }

    function receiveProduct() external onlyBuyer {
        if (s_depositorsCount < 3) {
            revert EscrowPayment__IncompleteDeposits();
        }

        s_amountWithdrawable[s_depositors.seller] += s_amountWithdrawable[msg.sender];
        s_amountWithdrawable[msg.sender] = 0;
        s_transactionCompleted = true;
    }

    function cancel(bool hasIssue) external onlyBuyer {
        if (!hasIssue) {
            _payCourierReturnFee(msg.sender);
            _payInconvenienceFee(msg.sender);
        }
        else {
            s_buyerFiledDispute = true;
        }
    }

    function resolveDispute(bool reallyHasIssue) external onlyCourier hasDispute {
        if (reallyHasIssue) {
            _payCourierReturnFee(s_depositors.seller);
        }
        else {
            address buyer = s_depositors.buyer;
            _payCourierReturnFee(buyer);
            _payInconvenienceFee(buyer);
        }
    }

    function receiveReturnedProduct() external onlySeller {}

    ////////////////////////////
    // Private Functions      //
    ////////////////////////////

    function _depositAsBuyer() private {
        if (s_depositors.buyer != address(0)) {
            revert EscrowPayment__BuyerAlreadyDeposited();
        }
        s_depositors.buyer = msg.sender;
    }

    function _depositAsSeller() private {
        if (s_depositors.seller != address(0)) {
            revert EscrowPayment__SellerAlreadyDeposited();
        }
        s_depositors.seller = msg.sender;
    }

    function _depositAsCourier() private {
        if (s_depositors.courier != address(0)) {
            revert EscrowPayment__CourierAlreadyDeposited();
        }
        s_depositors.courier = msg.sender;
    }

    function _payCourierReturnFee(address payer) private {
        uint256 shippingFee = i_shippingFee;
        uint256 payerBalance = s_amountWithdrawable[payer];
        if (shippingFee < payerBalance) {
            s_amountWithdrawable[payer] -= shippingFee;
            s_amountWithdrawable[s_depositors.courier] += shippingFee;
        }
        else {
            s_amountWithdrawable[s_depositors.courier] += payerBalance;
            s_amountWithdrawable[payer] = 0;
        }
    }

    function _payInconvenienceFee(address buyer) private {
        uint256 inconvenienceFee = i_price * INCONVENIENCE_THRESHOLD / PRECISION;
        uint256 buyerBalance = s_amountWithdrawable[buyer];
        if (inconvenienceFee < buyerBalance) {
            s_amountWithdrawable[buyer] -= inconvenienceFee;
            s_amountWithdrawable[s_depositors.seller] += inconvenienceFee;
        }
        else {
            s_amountWithdrawable[s_depositors.seller] += buyerBalance;
            s_amountWithdrawable[buyer] = 0;
        }
    }

    //////////////////////////////////
    // External View Functions      //
    //////////////////////////////////

    function getDepositors() external view returns (Depositors memory) {
        return s_depositors;
    }
}
