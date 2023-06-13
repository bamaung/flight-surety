pragma solidity ^0.4.24;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    uint256 private constant AIRLINE_MIN_FUND_AMOUNT = 10 ether;
    uint256 private constant MAX_INSURE_LIMIT = 1 ether;

    FlightSuretyData private flightSuretyData;

    address private contractOwner; // Account used to deploy contract

    mapping (address => address[]) airlineVoters; // key: airline, value: array of voters

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        // Modify to call data contract's status
        require(isOperational(), "___Contract is currently not operational___");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "___Caller is not contract owner___");
        _;
    }

    modifier requireQualifyAirline(address airline) {
        require(
            flightSuretyData.isRegisteredAirline(airline),
            "___Airline is not registered___"
        );
         require(
            flightSuretyData.getAirlineFund(airline) >= AIRLINE_MIN_FUND_AMOUNT,
            "___Airline needs min fund amount to participate in contract___"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address dataContract) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *
     */
    event AirlineRegister(
        string airlineNmae,
        address airlineAddress
    );
    function registerAirline(string name, address airlineAddress)
        external
        requireIsOperational
        requireQualifyAirline(msg.sender)
    {
        require(flightSuretyData.isNewAirline(airlineAddress), "___Airline is already in queue___");

        flightSuretyData.addAirline(name, airlineAddress);
        airlineVoters[airlineAddress].push(msg.sender); // for duplicate check
        
        uint256 noa = flightSuretyData.getAirlineCount();
        if (noa < 4) {
            flightSuretyData.registerAirline(airlineAddress);
        }

        emit AirlineRegister(name, airlineAddress);
    }

    event AirlineVote(
        address airlineAddress,
        uint256 votes,
        bool success
    );
    function voteAirline(address airline)
        external
        requireIsOperational
        requireQualifyAirline(msg.sender)
    {
        require(flightSuretyData.isPendingAirline(airline), "___Airline is not in queue___");

        // duplicate check
        address[] memory voters = airlineVoters[airline];
        bool isDuplicate = false;
        for (uint i = 0; i < voters.length; i++) {
            if (msg.sender == voters[i]) {
                isDuplicate = true;
                break;
            }
        }

        require(!isDuplicate, "___Duplicate vote.___");

        airlineVoters[airline].push(msg.sender); // for duplicate check

        uint256 _votes = flightSuretyData.incVotes(airline);
        uint256 noa = flightSuretyData.getAirlineCount();
        
        if (_votes >= noa.div(2)) {
            flightSuretyData.registerAirline(airline);
            emit AirlineVote(airline, _votes, true);
        }

        emit AirlineVote(airline, _votes, false);
    }

    event AirlineAddFund(address airlineAddress, uint256 amount);

    function addFund(address airline) 
        external 
        payable 
        requireIsOperational 
    {
        require(flightSuretyData.isRegisteredAirline(airline), "___Airline is not registered___");
        flightSuretyData.addFund.value(msg.value)(airline);
        emit AirlineAddFund (airline, msg.value);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    event FlightRegister(string flightNumber, address airlineAddress, uint256 timestamp);

    function registerFlight(string _flightNumber, uint256 _timestamp) 
        external 
        requireIsOperational
        requireQualifyAirline(msg.sender)
    {
        flightSuretyData.registerFlight(msg.sender, _flightNumber, _timestamp);
        emit FlightRegister(_flightNumber, msg.sender, _timestamp);
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string flightNumber,
        uint256 timestamp,
        uint8 statusCode
    ) 
        internal
    {
        bytes32 flightKey = getFlightKey(airline, flightNumber, timestamp);
        flightSuretyData.updateFlightStatus(flightKey, statusCode);

        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.creditInsurees(flightKey);
        }
    }

    event BuyInsurance(address airline, string flightNumber, uint256 timestamp, uint256 amount);

    function buy(address airline, string flightNumber, uint256 timestamp) 
        external 
        payable 
        requireIsOperational
    {
        uint256 amt = msg.value;
        uint256 retAmt = 0;
        if (msg.value > MAX_INSURE_LIMIT) {
            retAmt = msg.value.sub(MAX_INSURE_LIMIT);
            amt = MAX_INSURE_LIMIT;
        }
        bytes32 flightKey = getFlightKey(airline, flightNumber, timestamp);
        flightSuretyData.buy.value(amt)(flightKey, msg.sender);

        // refund
        if (msg.value > MAX_INSURE_LIMIT) {
            msg.sender.transfer(retAmt);
        }

        emit BuyInsurance (airline, flightNumber, timestamp, amt);
    }

    event WithdrawCredit (address withdrawAddress, uint256 withdrawAmount);

    function withdraw() 
        external 
        requireIsOperational
    {
        uint256 withdrawAmount = flightSuretyData.withdraw(msg.sender);
        address withdrawAddress = msg.sender;
        emit WithdrawCredit (withdrawAddress, withdrawAmount);
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string flight,
        uint256 timestamp
    ) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                     // Account that requested status
        bool isOpen;                           // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
                                               // This lets us group responses and identify
                                               // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "___Registration fee is required___");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3]) {
        require(
            oracles[msg.sender].isRegistered,
            "___Not registered as an oracle___"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
            (oracles[msg.sender].indexes[1] == index) ||
            (oracles[msg.sender].indexes[2] == index),
            "___Index does not match oracle request___"
        );

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "___Flight or timestamp do not match oracle request___");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        string flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion
}

contract FlightSuretyData {
    function isOperational() public view returns (bool);

    function isNewAirline(address airline) external view returns (bool);

    function isPendingAirline(address airline) external view returns (bool);

    function isRegisteredAirline(address airline) external view returns (bool);

    function isFundedAirline(address airline) external view returns (bool);

    function getAirlineName(address airline) external view returns (uint256);

    function getAirlineFund(address airline) external view returns (uint256);

    function getAirlineVotes(address airline) external view returns (uint256);

    function incVotes(address airline) external returns (uint256);

    function getAirlineCount() external view returns (uint256);

    function addAirline(string _name, address _airlineAddress) external;

    function registerAirline(address _airlineAddress) external;

    function addFund(address airlineAddress) external payable;

    function registerFlight(address _airline, string _flightNumber, uint256 _timestamp) external;

    function isRegisteredFlight(bytes32 flight) public view returns (bool);

    function updateFlightStatus(bytes32 _flightKey, uint8 _statusCode) external;

    function buy(bytes32 _flightKey, address _passengerAddress) external payable;

    function getPassengerInsuredAmount(bytes32 _flightKey, address _passengerAddress) external view returns (uint256);

    function creditInsurees(bytes32 flightKey) external;

    function withdraw(address passengerAddress) external returns (uint256);
}
