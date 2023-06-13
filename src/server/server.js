import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

const REGISTRATION_FEE = web3.utils.toWei('1', 'ether');

// STATUS_CODE_UNKNOWN = 0
// STATUS_CODE_ON_TIME = 10, 
// STATUS_CODE_LATE_AIRLINE = 20, 
// STATUS_CODE_LATE_WEATHER = 30
// STATUS_CODE_LATE_TECHNICAL = 40
// STATUS_CODE_LATE_OTHER = 50
const STATUS_CODES = [0, 10, 20, 30, 40, 50]; 

const getRandomStatusCode = () => {
  return STATUS_CODES[Math.floor(Math.random() * 6)];
}

let indexes = {}; // key: account, value: [index]

(async function () {
	const accounts = await web3.eth.getAccounts();
	for (const account of accounts) {
		console.log('account: ', account)
		await flightSuretyApp.methods.registerOracle().send({
			from: account,
			value: REGISTRATION_FEE,
      gas: 6721975
		});

    indexes[account] = await flightSuretyApp.methods.getMyIndexes().call({from: account});
    
    console.log(`Oracle Registered: ${indexes[account][0]}, ${indexes[account][1]}, ${indexes[account][2]}`);
	}
})();


flightSuretyApp.events.OracleRequest({fromBlock: 0}, async function (error, event) {
    if (error) {
      console.log(error) 
    } else {
      // index, airline, flight, timestamp
      let index = event.returnValues[0];
      let airline = event.returnValues[1];
      let flight = event.returnValues[2];
      let timestamp = event.returnValues[3];

      const accounts = await web3.eth.getAccounts();
      for (const account of accounts) {
        for (const _index of indexes[account]) {
            if (index === _index) {
              try {
                await flightSuretyApp.methods.submitOracleResponse(
                  _index, airline, flight, timestamp, getRandomStatusCode()
                ).send({ from: account, gas: 5000000 });
                console.log(`Submitted Oracle Response : index = ${_index}, airline = ${airline}, flight = ${flight}, timestamp = ${timestamp}`);
              } catch (e) {
                console.log(extractErrorCode(e.message));
              }
            }
          }
      }


    }
});

flightSuretyApp.events.FlightStatusInfo({fromBlock: 0}, async function (error, event) {
  if (error) {
    console.log(error);
  } else {
    //airline, flight, timestamp, statusCode
    let airline = event.returnValues[0];
    let flight = event.returnValues[1];
    let timestamp = event.returnValues[2];
    let statusCode = event.returnValues[3];
    console.log(`FlightStatusInfo (airline: ${airline}, flight: ${flight}, timestamp: ${timestamp}, statusCode: ${statusCode}`)
  }
})

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
});

const extractErrorCode = (str) => {
  const delimiter = '___';
  const firstOccurence = str.indexOf(delimiter);
  if(firstOccurence == -1) {
      return "An error occured";
  }

  const secondOccurence = str.indexOf(delimiter, firstOccurence + 1);
  if(secondOccurence == -1) {
      return "An error occured";
  }

  //Okay so far
  return str.substring(firstOccurence + delimiter.length, secondOccurence);
}

export default app;


