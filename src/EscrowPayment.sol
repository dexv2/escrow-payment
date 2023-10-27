// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Anti-fraud Escrow Payment System
 * @author Vermont Phil Paguiligan (Decrow IT Solutions)
 * 
 * @custom:terms
 * Seller - the one who owns the product and wants to sell it securely.
 * Courier - the one who wants to earn by delivering the product from seller to buyer.
 * Buyer - the one who is willing to pay for the legitimate product.
 * 
 * This system is trustless which can do the transaction securely in either seller's,
 * buyer's, or courier's POV. No entity can defraud one another when using this system.
 * 
 * @notice Using this system requires deposit from all entities (buyer, seller, and courier).
 * Your deposit is secure inside the system and can be wthdrawn after completing the transaction.
 * This is required to prevent fraudulent acts from all sides since our goal is to have a
 * secure transactions that will protect both buyer, seller, and courier also.
 * 
 * @notice No other entity can withdraw the deposit except the buyer, seller, and courier.
 * 
 */
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
    error EscrowPayment__NoReturnProduct();

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

    ///////////////////////////////////
    // Constant State Variables      //
    ///////////////////////////////////
    uint256 private constant PRECISION = 100;

    ////////////////////////////////////
    // Immutable State Variables      //
    ////////////////////////////////////
    IERC20 private immutable i_tokenSelected;
    uint256 private immutable i_price;
    uint256 private immutable i_shippingFee;
    uint256 private immutable i_inconvenienceThreshold;

    //////////////////////////
    // State Variables      //
    //////////////////////////
    uint8 private s_depositorsCount;
    bool private s_transactionCompleted;
    bool private s_buyerFiledDispute;
    bool private s_courierReturnsProduct;
    Depositors private s_depositors;
    mapping (address depositor => uint256 amountWithdrawable) private s_amountWithdrawable;

    ////////////////////
    // Functions      //
    ////////////////////

    /**
     * @param price the price of the product being sold
     * @param tokenSelected the currency accepted by the seller (USDC/USDT)
     * @param depositorType buyer, seller, or courier. for this contructor, usually it is the seller who calls this
     * @param shippingFee amount of payment for the courier
     * @param inconvenienceThreshold the percentage of inconvenience fee to the product price
     * 
     * @notice Upon creating this contract, the depositor (seller) is already required to deposit.
     * Don't worry as you will be able to withdraw it later.
     */
    constructor(
        uint256 price,
        address tokenSelected,
        DepositorType depositorType,
        uint256 shippingFee,
        uint256 inconvenienceThreshold
    ) {
        i_price = price;
        i_shippingFee = shippingFee;
        i_tokenSelected = IERC20(tokenSelected);
        i_inconvenienceThreshold = inconvenienceThreshold;

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

    ///////////////////////////
    // Public Functions      //
    ///////////////////////////

    /**
     * @notice All entities (buyer, seller, or courier) involved in this transaction are required to deposit.
     * This is to ensure that no one is able to defraud anyone involved in this transaction.
     * When this transaction completes, the seller and courier will be able to get their deposit
     * The buyer's deposit will be transferred to seller as payment.
     * 
     * But the buyer can also cancel and get their deposit back.
     * 
     * For full details, check the other functions below.
     * 
     * @notice As a seller, ensure that buyer and courier have already deposited to secure your product.
     * 
     * @param depositorType which one is the depositor. either buyer, seller, or courier
     * 
     */
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

        uint256 price = i_price;
        s_amountWithdrawable[msg.sender] = price;
        bool success = i_tokenSelected.transferFrom(msg.sender, address(this), price);
        if (!success) {
            revert EscrowPayment__TransferFromFailed();
        }
        s_depositorsCount++;
    }

    /////////////////////////////
    // External Functions      //
    /////////////////////////////

    // follows CEI
    function withdraw() external {
        if (!s_transactionCompleted) {
            revert EscrowPayment__TransactionStillOngoing();
        }
        _withdraw();
    }

    function emergencyWithdraw() external {}

    /**
     * @notice The buyer should call this function when the courier already delivered the product.
     * 
     * Calling this function ends the transaction which does the action:
     * 1. Lets the courier withdraw their deposit.
     * 2. Lets the seller withdraw their deposit and the payment of the buyer.
     * 
     * @notice As a courier, ensure that the buyer calls this function after handing the product
     * in order for you to get your deposited amount.
     * 
     */
    function receiveProduct() external onlyBuyer {
        if (s_depositorsCount < 3) {
            revert EscrowPayment__IncompleteDeposits();
        }

        s_amountWithdrawable[s_depositors.seller] += s_amountWithdrawable[msg.sender];
        s_amountWithdrawable[msg.sender] = 0;
        s_transactionCompleted = true;
    }

    /**
     * @param hasIssue set this to true when the product delivered is not the same as advertised.
     * This function is made for the buyer and seller protection.
     * 
     * @notice setting hasIssue param to false means you believe the product is legitimate
     * and you just changed your mind so you don't want to buy it anymore. Doing so will make you
     * pay an inconvenience fee for the seller which will be deducted to the amount you've deposited.
     * 
     * Check the _payInconvenienceFee() function below to see the computation of inconvenience fee.
     * 
     * @notice setting hasIssue param to true doesn't end the transaction yet.
     * 
     * Here's what you may do next before or after calling this function:
     * 1. Report the product to the courier that the product is not the same as advertised.
     * 2. Show the courier your conversation with the seller to prove your point.
     * 3. Show the product advertisement to the courier.
     * 
     * @notice keep in mind that the courier has the power to confirm or decline your dispute.
     * 
     * Check the resolveDispute function below to see the full details of confirming and declining
     * of your dispute to the seller.
     * 
     */
    function cancel(bool hasIssue) external onlyBuyer {
        if (!hasIssue) {
            _payCourierReturnFee(msg.sender);
            _payInconvenienceFee(msg.sender);
        }
        else {
            s_buyerFiledDispute = true;
        }
    }

    /**
     * @notice this is the function to call by the courier if the buyer filed a dispute
     * after the buyer called the cancel function and set hasIssue param to true.
     * 
     * @param reallyHasIssue set this to true after you checked that the product is 
     * really not the same as advertised.
     * 
     * @notice depending on what you set in reallyHasIssue param, the corresponding
     * entity will pay your shipping fee to return the product.
     * 
     * Here's what will happen:
     * 1. setting reallyHasIssue to true, the seller will pay your return shipping fee.
     * 2. setting reallyHasIssue to false, the buyer will pay your return shipping fee. And
     * in addition, the buyer will also pay the seller the inconvenience fee.
     * 
     * Check the _payInconvenienceFee() function below to see the computation of inconvenience fee.
     * 
     */
    function resolveDispute(bool reallyHasIssue) external onlyCourier {
        if (!s_buyerFiledDispute) {
            revert EscrowPayment__NoDisputeFiled();
        }

        if (reallyHasIssue) {
            _payCourierReturnFee(s_depositors.seller);
        }
        else {
            address buyer = s_depositors.buyer;
            _payCourierReturnFee(buyer);
            _payInconvenienceFee(buyer);
        }
    }

    /**
     * @notice This function is to be called by the seller after the buyer cancelled the transaction
     * and the courier already resolved the dispute.
     * 
     * Check the cancel() and the resoveDispute() function above to see the process of returning the
     * product and see how you will be payed for the inconvenience fee.
     * 
     * Check the getAmountWithdrawable(address depositor) function and input your wallet address
     * to see the total amount you can withdraw after the transaction has ended.
     * 
     * Calling this function will end the transaction immediately and will let all the depositors 
     * including you as a seller to withdraw their remaining amount withdrawables.
     * 
     */
    function receiveReturnedProduct() external onlySeller {
        if (!s_courierReturnsProduct) {
            revert EscrowPayment__NoReturnProduct();
        }

        s_transactionCompleted = true;
    }

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

    /**
     * Since this is an individual transaction, cancelling or returning of product requires return shipping fee.
     * The courier will have the right to decide who will pay for the return shipping fee.
     * 
     * Here is how the courier should decide who will pay:
     * 1. If the buyer cancels even if there is no problem in the product, the buyer should handle the return fee.
     * 2. If the buyer cancels and they both (buyer and courier) checked that the product has a problem, the
     *    seller should handle the return fee.
     * 
     * @param payer The entity assigned by the courier to pay for the return shipping fee (either buyer or seller)
     * 
     * @notice The buyer will automatically shoulder the return fee if they cancel the transaction and input that the product has no issue, 
     * 
     */
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

        s_courierReturnsProduct = true;
    }

    /**
     * @param buyer the wallet address of the buyer stored into the system.
     * 
     * @notice In addition to the courier return fee, the buyer has to pay the inconvenience fee
     * if the buyer cancels and no issue on the product.
     * 
     * Sample computation of inconvenience fee:
     * 
     * let inconvenienceThreshold = 10 (%)
     * let price = $100 (USD)
     * PRECISION = 100 (%)
     * 
     * $100 USD * 10% / 100% = $10 USD
     * inconvenienceFee = $10 USD
     * 
     */
    function _payInconvenienceFee(address buyer) private {
        uint256 inconvenienceFee = i_price * i_inconvenienceThreshold / PRECISION;
        uint256 buyerBalance = s_amountWithdrawable[buyer];
        if (inconvenienceFee < buyerBalance) {
            s_amountWithdrawable[buyer] -= inconvenienceFee;
            s_amountWithdrawable[s_depositors.seller] += inconvenienceFee;
        }
        else {
            /**
             * If after paying the return delivery fee, there is not enough deposit
             * to deduct from the buyer, just the remaining amount will be deducted
             * from the buyer.
             * 
             * This will happen only when the price is very low, so the deposit will just
             * be enough for the return shipping fee and a little remaining balance.
             * 
             */
            s_amountWithdrawable[s_depositors.seller] += buyerBalance;
            s_amountWithdrawable[buyer] = 0;
        }
    }

    function _withdraw() private {
        uint256 amountWithdrawable = s_amountWithdrawable[msg.sender];
        if (amountWithdrawable <= 0) {
            revert EscrowPayment__NoOutstandingAmountWithdrawable();
        }

        s_amountWithdrawable[msg.sender] = 0;
        bool success = i_tokenSelected.transfer(msg.sender, amountWithdrawable);
        if (!success) {
            revert EscrowPayment__TransferFailed();
        }
    }

    //////////////////////////////////
    // External View Functions      //
    //////////////////////////////////

    function getDepositors() external view returns (Depositors memory) {
        return s_depositors;
    }

    function getAmountWithdrawable(address depositor) external view returns (uint256) {
        return s_amountWithdrawable[depositor];
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getInconvenienceThreshold() external view returns (uint256) {
        return i_inconvenienceThreshold;
    }
}
