# Anti-fraud Escrow Payment System

### Seller POV:
1. I want to sell my product to marketplace but I don't have my own transport service to deliver my product to the **Buyer**.
2. I can appoint a third party transport service to pickup my product and deliver to the **Buyer**.
3. My product is legit and I'm afraid the **Buyer** will cancel the transaction unreasonably.
4. I'm concerned about the possibility of the **Delivery Driver** taking my product without delivering it to the **Buyer**, leading to a potential scam.

### Buyer POV:
1. I saw a good product in marketplace and I want to buy it.
2. I'm afraid to get scammed online. I'm willing to pay when I'm sure the product is legit and I checked it personally.
3. I want to cancel the transaction if the product is not as advertised.

### Delivery Driver POV:
1. I want to earn by delivering products from **Sellers** to **Buyers**.
2. I'm afraid to get scammed if I pay upfront on behalf of the **Buyer** and I later find out the product is not legitimate.
3. If the transaction gets cancelled, means I have to return the product, so I want to be compensated for the return delivery.

This system is designed to prevent fraudulent activities involving specifically the **Buyer**, **Seller**, or the **Delivery Driver**.

### This is the fool proof design we have in mind:
- The **Buyer**, **Seller**, and the **Delivery Driver** will deposit an amount equivalent to the product price each.
- After the successful transaction:
   1. The **Buyer** will receive the product, and their deposit will be transferred to the **Seller** as payment.
   2. The **Seller** will get their full deposit back, plus the full deposit of the **Buyer** as payment.
   3. The **Delivery Driver** will get their full deposit back.
   4. Everyone is happy.
- If the transaction gets cancelled:
  - Case 1 - The product is not as advertised (**Seller** is fraud):
    1. The **Delivery Driver** will return the product to the fraud **Seller**.
    2. The **Seller** will get their deposit back, but will be deducted by the return delivery fee transferred to the **Delivery Driver**.
    3. The **Buyer** will get their full deposit back.
    4. The **Delivery Driver** will get their full deposit back, plus the return delivery fee.
    5. Prevented the scam and the **Seller** gets penalized.
  - Case 2 - The product is the same as advertised but the **Buyer** still cancelled (**Buyer** is fraud):
    1. The **Delivery Driver** will return the product to the legitimate **Seller**.
    2. The **Buyer** will get their deposit back but will be deducted by:
       - Return delivery fee to be transferred to the **Delivery Driver**.
       - Inconvenience fee to be transferred to the **Seller**.
    3. The **Seller** will get their product and full deposit back, plus the inconvenience fee.
    4. The **Delivery Driver** will get their full deposit back plus the return delivery fee.
    5. Prevented the fraudulent buying and the **Buyer** gets penalized.
  - The **Delivery Driver** will have the authority to decide who (**Buyer** or **Seller**) acts fraudulently.
- The **Delivery Driver** cannot take the product without delivering as they will not get their deposit back and that's not a wise thing to do.
