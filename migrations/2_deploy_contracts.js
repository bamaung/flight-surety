const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function(deployer) {
    deployer.deploy(FlightSuretyData)
        .then(() => {
            return deployer.deploy(FlightSuretyApp, FlightSuretyData.address)
        .then(() => {
            // Authorize App Contract.
            FlightSuretyData.at(FlightSuretyData.address).then((c) => c.authorizeCaller(FlightSuretyApp.address));
        }).then(() => {
            let config = {
                localhost: {
                    url: 'http://127.0.0.1:8545',
                    dataAddress: FlightSuretyData.address,
                    appAddress: FlightSuretyApp.address
                }
            }
            fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
            fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
        });
    });
}