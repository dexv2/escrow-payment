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
    error EscrowPayment__AlreadyDeposited(DepositorType depositorType, address depositor);
    error EscrowPayment__IncompleteDeposits();
    error EscrowPayment__NoOutstandingAmountWithdrawable();
    error EscrowPayment__TransactionStillOngoing();
    error EscrowPayment__NoDisputeFiled();
    error EscrowPayment__NoReturnProduct();
    error EscrowPayment__NotAllowedWhenAllHaveDeposited();
    error EscrowPayment__NotYetIdle();
    error EscrowPayment__NotEOA();

    ////////////////
    // Enums      //
    ////////////////
    enum DepositorType { NONE, BUYER, SELLER, COURIER }

    //////////////////
    // Structs      //
    //////////////////
    struct DepositorInfo {
        DepositorType depositorType;
        uint256 amountWithdrawable;
    }

    ///////////////////////////////////
    // Constant State Variables      //
    ///////////////////////////////////
    uint256 private constant PRECISION = 100;
    // 3 hours minimum waiting time before the depositor can
    // emergency withdraw when the number of depositors
    // required is not satisfied.
    uint256 private constant MIN_WAITING_TIME = 10800;

    ////////////////////////////////////
    // Immutable State Variables      //
    ////////////////////////////////////
    IERC20 private immutable i_tokenSelected;
    uint256 private immutable i_price;
    uint256 private immutable i_returnShippingFee;
    uint256 private immutable i_inconvenienceThreshold;
    address private immutable i_factory;
    uint256 private immutable i_escrowCreatedTime;

    //////////////////////////
    // State Variables      //
    //////////////////////////
    uint8 private s_depositorsCount;
    bool private s_transactionCompleted;
    bool private s_buyerFiledDispute;
    bool private s_courierReturnsProduct;
    /**
     * @dev Made these 2 mappings which may seem a redundant but it's not.
     * 
     * s_depositor is used to check if there is an existing depositor in this type.
     * example: you have deposited as buyer, but you have forgotten it and deposited again.
     * outcome: depositing again will revert since the buyer type depositor is already occupied.
     * 
     * s_depositorInfo is used to check the informations of the depositor which also contains depositorType value.
     * The depositorType in this object is used to be the object key in s_depositor mapping which is used to search and
     * set the value of depositor in s_depositor mapping to address(0) in emergencyWithdraw() function in order to
     * clear the depositor details without searching individually whether the msg sender is buyer, seller, or courier.
     * 
     * May refactor soon if there is a better solution.
     */
    mapping (address depositor => DepositorInfo depositorInfo) private s_depositorInfo;
    mapping (DepositorType depositorType => address depositor) private s_depositor;

    /////////////////
    // Events      //
    /////////////////
    event Deposited(
        address indexed depositor,
        uint8 depositorType,
        uint256 amountDeposit,
        uint8 depositorCount
    );

    event Withdrawn(
        address indexed depositor,
        uint8 depositorType,
        uint256 amountWithdrawn,
        bool isEmergencyWithdraw
    );

    event Cancelled(
        uint256 inconvenienceFeePayed,
        uint256 returnDeliveryFeePayed,
        bool productHasIssue
    );

    event Completed(bool isReturned, int256 sellerGainOrLoss);

    ////////////////////
    // Functions      //
    ////////////////////

    /**
     * @param price the price of the product being sold
     * @param tokenSelected the currency accepted by the seller (USDC/USDT)
     * @param returnShippingFee amount of payment for the courier when required to return the product
     * @param inconvenienceThreshold the percentage of inconvenience fee to the product price
     * 
     * @notice shipping fee should be paid upfront to the courier before delivering the product.
     * And returnShippingFee should be equal to the shipping fee paid upfront, or depending on your agreement
     * with the courier.
     * 
     */
    constructor(
        uint256 price,
        address tokenSelected,
        uint256 returnShippingFee,
        uint256 inconvenienceThreshold
    ) {
        i_price = price;
        i_returnShippingFee = returnShippingFee;
        i_tokenSelected = IERC20(tokenSelected);
        i_inconvenienceThreshold = inconvenienceThreshold;
        i_factory = msg.sender;
        i_escrowCreatedTime = block.timestamp;
    }

    ////////////////////
    // Modifiers      //
    ////////////////////

    modifier onlyBuyer() {
        if (msg.sender != _getBuyer()) {
            revert EscrowPayment__NotABuyer();
        }
        _;
    }

    modifier onlySeller() {
        if (msg.sender != _getSeller()) {
            revert EscrowPayment__NotASeller();
        }
        _;
    }

    modifier onlyCourier() {
        if (msg.sender != _getCourier()) {
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
        if (msg.sender != tx.origin) {
            revert EscrowPayment__NotEOA();
        }

        _deposit(depositorType, msg.sender);
    }

    /////////////////////////////
    // External Functions      //
    /////////////////////////////

    /**
     * @dev follows CEI
     * @notice No other entity can withdraw the deposit except the buyer, seller, and courier.
     * 
     */
    function withdraw() external {
        if (!s_transactionCompleted) {
            revert EscrowPayment__TransactionStillOngoing();
        }

        (DepositorType depositorType, uint256 amountWithdrawable) = _getDepositorInfo(msg.sender);
        s_depositorInfo[msg.sender].amountWithdrawable = 0;

        _withdraw(amountWithdrawable);

        emit Withdrawn(msg.sender, uint8(depositorType), amountWithdrawable, false);
    }

    /**
     * @notice The depositor can call this function if the other entities involved have backed out
     * or didn't deposit so the transaction will not progress anymore.
     * 
     * @notice The waiting time before the depositor can withdraw is 3 hours.
     * 
     * In this case, the depositor can withdraw their deposit.
     */
    function emergencyWithdraw() external {
        if (s_depositorsCount > 2) {
            revert EscrowPayment__NotAllowedWhenAllHaveDeposited();
        }
        if (!_isIdle()) {
            revert EscrowPayment__NotYetIdle();
        }

        (DepositorType depositorType, uint256 amountWithdrawable) = _getDepositorInfo(msg.sender);

        /// remove the depositor from the list
        s_depositorsCount--;
        s_depositor[depositorType] = address(0);

        /// clear the depositor's information
        DepositorInfo memory depositorInfo;
        s_depositorInfo[msg.sender] = depositorInfo;

        _withdraw(amountWithdrawable);

        emit Withdrawn(msg.sender, uint8(depositorType), amountWithdrawable, true);
    }

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

        uint256 buyerPaymentAmount = _getAmountWithdrawable(msg.sender);
        s_depositorInfo[msg.sender].amountWithdrawable = 0;
        s_transactionCompleted = true;
        s_depositorInfo[_getSeller()].amountWithdrawable += buyerPaymentAmount;

        emit Completed(false, int256(buyerPaymentAmount));
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
        if (hasIssue) {
            s_buyerFiledDispute = true;
            return;
        }

        uint256 returnDeliveryFee = _payCourierReturnFee(msg.sender);
        uint256 inconvenienceFee = _payInconvenienceFee(msg.sender);

        emit Cancelled(inconvenienceFee, returnDeliveryFee, false);
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

        uint256 inconvenienceFee;
        uint256 returnDeliveryFee;

        if (reallyHasIssue) {
            returnDeliveryFee = _payCourierReturnFee(_getSeller());
        }
        else {
            address buyer = _getBuyer();
            returnDeliveryFee = _payCourierReturnFee(buyer);
            inconvenienceFee = _payInconvenienceFee(buyer);
        }

        emit Cancelled(inconvenienceFee, returnDeliveryFee, reallyHasIssue);
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

        uint256 sellerAmountWithdrawable = _getAmountWithdrawable(s_depositor[DepositorType.SELLER]);
        int256 sellerGainOrLoss = int256(int256(sellerAmountWithdrawable) - int256(i_price));

        s_transactionCompleted = true;
        emit Completed(true, sellerGainOrLoss);
    }

    ////////////////////////////
    // Private Functions      //
    ////////////////////////////

    function _deposit(DepositorType depositorType, address depositor) private {
        /**
         * Check if there is an existing depositor.
         * 
         * Then fill the depositor mapping if there isn't any,
         * to make sure there wouldn't be a deposit duplication.
         * 
         */
        address existingDepositor = s_depositor[depositorType];
        if (existingDepositor != address(0)) {
            revert EscrowPayment__AlreadyDeposited(depositorType, existingDepositor);
        }
        s_depositor[depositorType] = depositor;

        uint256 price = i_price;
        DepositorInfo memory depositorInfo;
        depositorInfo.depositorType = depositorType;
        depositorInfo.amountWithdrawable = price;
        s_depositorInfo[depositor] = depositorInfo;

        bool success = i_tokenSelected.transferFrom(depositor, address(this), price);
        if (!success) {
            revert EscrowPayment__TransferFromFailed();
        }
        s_depositorsCount++;

        emit Deposited(depositor, uint8(depositorType), price, s_depositorsCount);
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
    function _payCourierReturnFee(address payer) private returns (uint256) {
        uint256 returnShippingFee = i_returnShippingFee;
        uint256 payerBalance = _getAmountWithdrawable(payer);
        if (returnShippingFee < payerBalance) {
            s_depositorInfo[payer].amountWithdrawable -= returnShippingFee;
            s_depositorInfo[_getCourier()].amountWithdrawable += returnShippingFee;
        }
        else {
            s_depositorInfo[_getCourier()].amountWithdrawable += payerBalance;
            s_depositorInfo[payer].amountWithdrawable = 0;
        }

        s_courierReturnsProduct = true;
        return returnShippingFee;
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
    function _payInconvenienceFee(address buyer) private returns (uint256) {
        uint256 inconvenienceFee = i_price * i_inconvenienceThreshold / PRECISION;
        uint256 buyerBalance = _getAmountWithdrawable(buyer);
        if (inconvenienceFee < buyerBalance) {
            s_depositorInfo[buyer].amountWithdrawable -= inconvenienceFee;
            s_depositorInfo[_getSeller()].amountWithdrawable += inconvenienceFee;
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
            s_depositorInfo[_getSeller()].amountWithdrawable += buyerBalance;
            s_depositorInfo[buyer].amountWithdrawable = 0;
        }

        return inconvenienceFee < buyerBalance ? inconvenienceFee : buyerBalance;
    }

    function _withdraw(uint256 amountWithdrawable) private {
        if (amountWithdrawable <= 0) {
            revert EscrowPayment__NoOutstandingAmountWithdrawable();
        }

        bool success = i_tokenSelected.transfer(msg.sender, amountWithdrawable);
        if (!success) {
            revert EscrowPayment__TransferFailed();
        }
    }

    /////////////////////////////////
    // Private View Functions      //
    /////////////////////////////////

    function _idleTime() private view returns (uint256) {
        return block.timestamp - i_escrowCreatedTime;
    }

    function _isIdle() private view returns (bool) {
        return _idleTime() > MIN_WAITING_TIME;
    }

    function _getBuyer() private view returns (address) {
        return s_depositor[DepositorType.BUYER];
    }

    function _getSeller() private view returns (address) {
        return s_depositor[DepositorType.SELLER];
    }

    function _getCourier() private view returns (address) {
        return s_depositor[DepositorType.COURIER];
    }

    function _getAmountWithdrawable(address depositor) private view returns (uint256) {
        return s_depositorInfo[depositor].amountWithdrawable;
    }

    function _getDepositorInfo(address depositor) private view returns (DepositorType, uint256) {
        DepositorInfo memory info = s_depositorInfo[depositor];
        return (info.depositorType, info.amountWithdrawable);
    }

    //////////////////////////////////
    // External View Functions      //
    //////////////////////////////////

    function getAmountWithdrawable(address depositor) external view returns (uint256) {
        return _getAmountWithdrawable(depositor);
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getInconvenienceThreshold() external view returns (uint256) {
        return i_inconvenienceThreshold;
    }

    function getFactory() external view returns (address) {
        return i_factory;
    }

    function getDepositorsCount() external view returns (uint8) {
        return s_depositorsCount;
    }

    function getDepositorInfo(address depositor) external view returns (DepositorType, uint256) {
        return _getDepositorInfo(depositor);
    }

    function getSeller() external view returns (address) {
        return _getSeller();
    }

    function getBuyer() external view returns (address) {
        return _getBuyer();
    }

    function getCourier() external view returns (address) {
        return _getCourier();
    }
}
