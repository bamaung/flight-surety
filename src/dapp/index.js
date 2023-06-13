
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {
    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            display('display-wrapper-opt-status', 'Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        // Register airline
        DOM.elid('register-airline').addEventListener('click', () => {
            let airlineName = DOM.elid('airline-name').value;
            let airlineAddress = DOM.elid('airline-address-1').value;
            contract.registerAirline(airlineName, airlineAddress, (error, result) => {
                display("display-wrapper-airline", 'Register airline', "Airline addr: " + airlineAddress, [{ label: 'Register airline', error: error, value: result }]);
            });
        });

        // Check airline status
        DOM.elid('check-airline-status').addEventListener('click', () => {
            let airlineAddress = DOM.elid('airline-address-2').value;
            contract.isRegisteredAirline(airlineAddress, (error, result) => {
                display("display-wrapper-airline", 'Check airline status', "Airline addr: " + airlineAddress, [{ label: 'Is Airline registered', error: error, value: result }]);
            });
        });

        DOM.elid('check-airline-status').addEventListener('click', () => {
            let airlineAddress = DOM.elid('airline-address-2').value;
            contract.isFundedAirline(airlineAddress, (error, result) => {
                display("display-wrapper-airline", 'Check airline status', "Airline addr: " + airlineAddress, [{ label: 'Is Airline funded', error: error, value: result }]);
            });
        });

        DOM.elid('check-airline-status').addEventListener('click', () => {
            let airlineAddress = DOM.elid('airline-address-2').value;
            contract.isPendingAirline(airlineAddress, (error, result) => {
                display("display-wrapper-airline", 'Check airline status', "Airline addr: " + airlineAddress, [{ label: 'Is Airline pending', error: error, value: result }]);
            });
        });

        // Fund airline
        DOM.elid('fund-airlines').addEventListener('click', () => {
            let airlineAddress = DOM.elid('airline-address-2').value;
            contract.addFund(airlineAddress, (error, result) => {
                display("display-wrapper-airline", 'Fund airline', "Airline addr: " + airlineAddress, [{ label: 'Add fund', error: error, value: result }]);
            });
        });

        // Vote airline
        DOM.elid('vote-airlines').addEventListener('click', () => {
            let airlineAddress = DOM.elid('airline-address-2').value;
            contract.voteAirline(airlineAddress, (error, result) => {
                display("display-wrapper-airline", 'Vote airline', "Airline addr: " + airlineAddress, [{ label: 'Vote', error: error, value: result }]);
            });
        });

        // Register Flight
        DOM.elid('register-flight').addEventListener('click', () => {
            let flightNumber = DOM.elid('flight-number-1').value;
            let timestamp = DOM.elid('timestamp').value;
            contract.registerFlight(flightNumber, timestamp, (error, result) => {
                display("display-wrapper-flight", 'Register flight', "Flight: " + flightNumber, [{ label: 'Register flight', error: error, value: result }]);
            });
        });

        // Fetch flight status
        DOM.elid('fetch-flight-status').addEventListener('click', () => {
            let flightNumber = DOM.elid('flight-number-2').value;
            let airlineAddress = DOM.elid('airline-address-3').value;
            let timestamp = DOM.elid('timestamp').value;
            contract.fetchFlightStatus(flightNumber, airlineAddress, timestamp, (error, result) => {
                display("display-wrapper-flight-insurance", 'Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        });

        // Buy flight insurance
        DOM.elid('buy-insurance').addEventListener('click', () => {
            let flightNumber = DOM.elid('flight-number-2').value;
            let airlineAddress = DOM.elid('airline-address-3').value;
            let timestamp = DOM.elid('timestamp').value;
            let amount = DOM.elid('amount').value;
            contract.buyInsurance(airlineAddress, flightNumber, timestamp, amount, (error, result) => {
                display("display-wrapper-flight-insurance", 'Buy flight insurance', '', [ { label: 'Buy', error: error, value: result} ]);
            });
        });

        // Withdraw credit
        DOM.elid('withdraw-credit').addEventListener('click', () => {
            contract.withdrawCredit((error, result) => {
                display("display-wrapper-passenger", 'Withdraw', '', [ { label: 'withdraw', error: error, value: result} ]);
            });
        });

        // Check credit balance
        DOM.elid('check-credit-balance').addEventListener('click', () => {
            contract.getPassengerCreditBalance((error, result) => {
                display("display-wrapper-passenger", 'Balance', '', [ { label: 'credit', error: error, value: result} ]);
            });
        });
    });
})();


function display(displayId, title, description, results) {
    let displayDiv = DOM.elid(displayId);
    let section = DOM.section();
    section.appendChild(DOM.h4(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? extractErrorCode(result.error.message) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}

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







