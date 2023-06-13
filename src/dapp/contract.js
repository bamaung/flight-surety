import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {
        let config = Config[network];
        this.owner = null;
        if (window.ethereum) {
            this.web3 = new Web3(window.ethereum);
            window.ethereum.request({ method: 'eth_requestAccounts' }).then(accounts => {
                this.owner = accounts[0];
                console.log(this.owner);
                this.web3.eth.defaultAccount = accounts[0];
                callback();
            });

            window.ethereum.on('accountsChanged', accounts => {
                this.owner = accounts[0];
                this.web3.eth.defaultAccount = accounts[0];
                console.log(this.owner);
            });
        } else {
            this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        }
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.appAddress = config.appAddress;
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    isRegisteredAirline(address, callback) {
        let self = this;
        self.flightSuretyData.methods
            .isRegisteredAirline(address)
            .call({ from: self.owner}, callback);
    }

    isFundedAirline(address, callback) {
        let self = this;
        self.flightSuretyData.methods
            .isFundedAirline(address)
            .call({ from: self.owner}, callback);
    }

    isPendingAirline(address, callback) {
        let self = this;
        self.flightSuretyData.methods
            .isPendingAirline(address)
            .call({ from: self.owner}, callback);
    }

    addFund(address, callback) {
        let self = this;
        const amount = this.web3.utils.toWei('10', 'ether');
        self.flightSuretyApp.methods
            .addFund(address)
            .send({ from: self.owner, value: amount}, callback);
    }

    registerAirline(name, address, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .registerAirline(name, address)
            .send({ from: self.owner}, callback);
    }

    voteAirline(address, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .voteAirline(address)
            .send({ from: self.owner}, callback);
    }

    registerFlight(flightNumber, timestamp, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .registerFlight(flightNumber, timestamp)
            .send({ from: self.owner}, callback);
    }

    buyInsurance(airlineAddress, flightNumber, timestamp, amount, callback) {
        let self = this;
        const _amount = this.web3.utils.toWei(amount, 'ether');
        console.log(amount);
        console.log(_amount);
        self.flightSuretyApp.methods
            .buy(airlineAddress, flightNumber, timestamp)
            .send({ from: self.owner, value: _amount}, callback);
    }

    withdrawCredit(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .withdraw()
            .send({ from: self.owner}, callback);
    }

    getPassengerCreditBalance(callback) {
        let self = this;
        self.flightSuretyData.methods
            .getPassengerCreditBalance()
            .call( { from: self.owner }, callback);
    }

    fetchFlightStatus(flightNumber, airlineAddress, timestamp, callback) {
        let self = this;
        let payload = {
            airline: airlineAddress,
            flight: flightNumber,
            timestamp: timestamp
        }
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner }, (error, result) => {
                callback(error, payload);
            });
    }
}