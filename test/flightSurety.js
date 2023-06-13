
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  let airline1 = accounts[0];
  let airline2 = accounts[1];
  let airline3 = accounts[2];
  let airline4 = accounts[3];
  let airline5 = accounts[4];
  let airline6 = accounts[5];
  let airline7 = accounts[6];

  let amount10Ether = 10 * 10**18;

  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline("new airline", newAirline, {from: config.firstAirline});
    }
    catch(e) {
        
    }
    let result = await config.flightSuretyData.isRegisteredAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  // Airline Contract Initialization - First airline is registered when contract is deployed.
  it('(airline) First airline should be registered when contract is deployed', async () => {
    let result = await config.flightSuretyData.isRegisteredAirline.call(accounts[0]);
    assert.equal(result, true, "First airline should be registered when contract is deployed.");
  });

  // Multiparty Consensus - Only existing airline may register a new airline until there are at 
  // least four airlines registered
  it('(airline) first 4 airlines can register without multiparty consensus', 
          async () => {
    // ARRANGE
    await config.flightSuretyApp.addFund(airline1, {value: amount10Ether}); // airline1 funded.

    // ACT
    // first 4 airlines can register without multiparty Consensus
    await config.flightSuretyApp.registerAirline("Second Airline", airline2, {from: airline1});
    await config.flightSuretyApp.registerAirline("Third Airline", airline3, {from: airline1});
    await config.flightSuretyApp.registerAirline("Fourth Airline", airline4, {from: airline1});

    let regAirline2 = await config.flightSuretyData.isRegisteredAirline(airline2);
    let regAirline3 = await config.flightSuretyData.isRegisteredAirline(airline3);
    let regAirline4 = await config.flightSuretyData.isRegisteredAirline(airline4);

    // ASSERT
    assert.equal(regAirline2, true, "Second airline should be register.");
    assert.equal(regAirline3, true, "Third airline should be register.");
    assert.equal(regAirline4, true, "Fourth airline should be register.");
  });

  // Multiparty Consensus - Registration of fifth and subsequent airlines requires multi-party 
  // consensus of 50% of registered airlines
  it('(airline) fifth and subsequent airlines require 50% votes.', 
          async () => {
    // ARRANGE
    // requires multi-party consensus of 50% of registered airlines
    await config.flightSuretyApp.registerAirline("Fifth Airline", airline5, {from: airline1});

    // ACT
    let _airline5 = await config.flightSuretyData.isRegisteredAirline(airline5);

    // airline2 funded.
    await config.flightSuretyApp.addFund(airline2, {value: amount10Ether}); 

    // fifth airline is voted by second airline.
    await config.flightSuretyApp.voteAirline(airline5, {from: airline2});

    let regAirline5 = await config.flightSuretyData.isRegisteredAirline(airline5);

    // ASSERT
    assert.equal(_airline5, false, "Fifth ariline needed 50% votes");
    assert.equal(regAirline5, true, "Fifth ariline get 50% votes");
  });
 
  // Airline Ante - Airline can be registered, but does not participate in contract 
  // until it submits funding of 10 ether (make sure it is not 10 wei)
  it('(airline) funding of 10 ether require to participate in contract', async () => {
    // ARRANGE
    await config.flightSuretyApp.registerAirline("6th airline", airline6, {from: airline1});
    
    // airline6 needs 50% vote to get registered.
    await config.flightSuretyApp.voteAirline(airline6, {from: airline2}); // vote from airline2

    // ACT
    try {
      // airline6 is not funded and expected to fail.
      await config.flightSuretyApp.registerAirline("7th Airline", airline7, {from: airline6});
    } catch (e) {

    }

    let result1 = await config.flightSuretyData.isPendingAirline.call(airline7);

    // airline6 funded.
    await config.flightSuretyApp.addFund(airline6, {value: amount10Ether}); 

    try {
      await config.flightSuretyApp.registerAirline("7th Airline", airline7, {from: airline6});
    } catch (e) {

    }

    let result2 = await config.flightSuretyData.isPendingAirline.call(airline7);

    // ASSERT
    assert.equal(result1, false, "registerion should fail because not funded or fund < 10 ether");
    assert.equal(result2, true, "registerion should success after 10 ether funded");
  });
});
