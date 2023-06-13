# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Libraries and tools used

    nodejs v10.24.1
    npm 6.14.12
    Truffle v5.0.2 (core: 5.0.2)
    Solidity v0.4.24 (solc-js)
    web3js 1.0.0-beta.37


## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`

## To run truffle tests:

`truffle develop`

`> compile`

`> test`

## To use the dapp:

`npm run ganache`

`truffle compile`

`truffle migrate`

`npm run server`

`npm run dapp`

To view dapp:

`http://localhost:8000`

## UI walkthrough

![Ariline Actions](images/reg-airline.png)

- first airline `accounts[0]` is registered at smart contract deployed time, but it is required to add fund  (10 ETH) in order to participate in the contract.

- The first four airlines that register through this form will be automatically flag as "registered." Following the fourth airline, "registered" status will require a 50% vote from existing airlines.

![Register Flight](images/reg-flight.png)

- Airlines who have funded their accounts with a minimum of 10 ETH are eligible to register their flights.

![Flight insurance](images/flight-insurance.png)

- Passengers have the option to purchase insurance for flights that have been registered by airlines in the "Register Flight" section.

![Passenger Details](images/passenger-details.png)


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)