## Assumptions: 

- The Hermes Protocol is allowed to burn PLTS and mint Hermes within the same transaction. This eliminates the need for trading on the public market.
- The Hermes treasury maintains its liquidity position, allowing for direct swaps between PLTS and HERMES (and earns trading fees).
- PLTS will continue to be tradable, and this trading volume will support the bank. As there would be a direct $ to $ conversion between PLTS and Hermes, arbitrage opportunities would exist to balance PLTS price, bank rewards, and Hermes price. Thus, PLTS would continue to have utility as a bank-funding mechanism until all PLTS has been burned or the bank is discontinued.
- The transition will be handled over the course of 1+ weeks to ensure price stability.
- The user allows an additional smart contract to directly withdraw their PLTS from the bank in order to mint new Hermes (and receive their bonus rewards). This contract will also be responsible for a one-way PLTS to Hermes conversion at a given ratio (to be determined), but without bonus rewards from locking it in the bank.


### Actions from the user:

- Approves the Swap contract to withdraw their PLTS in the bank.
- Input the amount of PLTS you wish to swap (and get an estimate of their bonus token reward) and send the transaction to the Swap contract.
- Receives Hermes in their wallet from the Swap contract.


### Actions by the smart contract:

- Looks up the user's bonus reward via wallet address and serves this in the interface.
Receives PLTS, and mints Hermes at the given ratio.
- Burns PLTS.
- Sends Hermes to the user.
