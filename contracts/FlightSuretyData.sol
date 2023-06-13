pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    uint256 private constant AIRLINE_MIN_FUND_AMOUNT = 10 ether;
    uint256 private constant MAX_INSURE_LIMIT = 1 ether;

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    mapping(address => uint256) private authorizedAppContracts;

    uint256 totalFund;

    struct Airline {
        string name;
        address airlineAddress;
        uint256 fund;
        bool isRegistered;
        uint256 votes;
    }
    mapping(address => Airline) private airlines;
    uint256 private airlineCount = 0;

    struct Flight {
        string flightNumber;
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        address[] insurees;
    }
    mapping(bytes32 => Flight) private flights;

    struct Passenger {
        address passengerAddress;
        uint256 credit;
        mapping(bytes32 => uint256) flightInsurances;
    }
    mapping(address => Passenger) private passengers;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() public {
        contractOwner = msg.sender;
        // register first airline
        airlines[msg.sender] = Airline (
            {
                name: "First Airline", 
                airlineAddress: msg.sender, 
                fund: 0, 
                isRegistered: true, 
                votes: 0
            });

        airlineCount = airlineCount.add(1);
    }

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
        require(operational, "___Contract is currently not operational___");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "___Caller is not contract owner___");
        _;
    }

    modifier requireAuthorizedAppContract() {
        require(
            authorizedAppContracts[msg.sender] == 1,
            "___Caller AppContract is not authorized___"
        );
        _;
    }

    modifier requireRegisteredFlight(bytes32 flightKey) {
        require(flights[flightKey].isRegistered, "___Flight is not registered___");
        _;
    }

    modifier requireInsuredPassenger(address passengerAddress) {
        require(passengers[passengerAddress].passengerAddress != address(0), "___Passenger is not insured___");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    function isNewAirline(address airline) external view returns (bool) {
        return airlines[airline].airlineAddress == address(0);
    }

    function isPendingAirline(address airline) external view returns (bool) {
        return
            airlines[airline].airlineAddress != address(0) &&
            airlines[airline].isRegistered == false;
    }

    function isRegisteredAirline(address airline) external view returns (bool) {
        return airlines[airline].isRegistered;
    }

    function isFundedAirline(address airline) public view returns (bool) {
        return airlines[airline].fund > 0;
    }

    function getAirlineName(address airline) external view returns (string) {
        return airlines[airline].name;
    }

    function getAirlineFund(address airline) external view returns (uint256) {
        return airlines[airline].fund;
    }
    
    function getAirlineVotes(address airline) external view returns (uint256) {
        return airlines[airline].votes;
    }

    function getAirlineCount() external view returns (uint256) {
        return airlineCount;
    }

    function isRegisteredFlight(bytes32 flightKey) public view returns (bool) {
        return flights[flightKey].isRegistered;
    }

    function incVotes(address airline) 
        external
        requireIsOperational
        requireAuthorizedAppContract
        returns (uint256) 
    {
        airlines[airline].votes = airlines[airline].votes.add(1);
        return airlines[airline].votes;
    }

    function getPassengerInsuredAmount(bytes32 _flightKey, address _passengerAddress) 
        external 
        view
        returns (uint256)
    {
        return passengers[_passengerAddress].flightInsurances[_flightKey];
    }

    function getPassengerCreditBalance()
        external
        view
        returns (uint256)
    {
        return passengers[msg.sender].credit;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function addAirline(string _name, address _airlineAddress) 
        external 
        requireIsOperational
        requireAuthorizedAppContract
    {
        airlines[_airlineAddress] = Airline({
            name: _name,
            airlineAddress: _airlineAddress,
            fund: 0,
            isRegistered: false,
            votes: 1
        });
    }

    function registerAirline(address airlineAddress) 
        external
        requireIsOperational
        requireAuthorizedAppContract
    {
        airlines[airlineAddress].isRegistered = true;
        airlineCount = airlineCount.add(1);
    }

    function addFund(address airlineAddress) 
        external 
        payable 
        requireIsOperational 
        requireAuthorizedAppContract 
    {
        airlines[airlineAddress].fund = airlines[airlineAddress].fund.add(msg.value);
        totalFund = totalFund.add(msg.value);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(address _airline, string _flightNumber, uint256 _timestamp) 
        external 
        requireIsOperational
        requireAuthorizedAppContract
    {
        bytes32 key = getFlightKey(_airline, _flightNumber, _timestamp);
        require(!flights[key].isRegistered, "___Flight is already registered___");

        flights[key] = Flight({
            flightNumber: _flightNumber,
            isRegistered: true,
            statusCode: STATUS_CODE_UNKNOWN,
            updatedTimestamp: _timestamp,
            airline: _airline,
            insurees: new address[](0)
        });
    }

    function updateFlightStatus(bytes32 _flightKey, uint8 _statusCode) 
        external 
        requireIsOperational
        requireAuthorizedAppContract
        requireRegisteredFlight(_flightKey)
    {
        flights[_flightKey].statusCode = _statusCode;
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(bytes32 _flightKey, address _passengerAddress) 
        external 
        payable 
        requireIsOperational
        requireAuthorizedAppContract 
        requireRegisteredFlight(_flightKey)
    {
        bool isDuplicate = false;
        for(uint256 i; i < flights[_flightKey].insurees.length; i++)
        {
            if (flights[_flightKey].insurees[i] == _passengerAddress) {
                isDuplicate = true;
            }
        }

        require(!isDuplicate, "___Passenger already bought for this flight___");

        if (passengers[_passengerAddress].passengerAddress == address(0)) {
            // New passenger
            passengers[_passengerAddress] = Passenger ({
                passengerAddress: _passengerAddress,
                credit: 0
            });
        } 

        flights[_flightKey].insurees.push(_passengerAddress);       

        passengers[_passengerAddress].flightInsurances[_flightKey] = msg.value;
        totalFund = totalFund.add(msg.value);
    }
    

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees(bytes32 _flightKey) 
        external 
        requireAuthorizedAppContract 
        requireRegisteredFlight(_flightKey)
    {
        for(uint256 i; i < flights[_flightKey].insurees.length; i++)
        {
            address _passengerAddress = flights[_flightKey].insurees[i];

            uint256 amount = passengers[_passengerAddress].flightInsurances[_flightKey];
            delete passengers[_passengerAddress].flightInsurances[_flightKey];

            if (amount > 0) {
                uint256 oldCredit = passengers[_passengerAddress].credit;
                passengers[_passengerAddress].credit = oldCredit + amount + amount.div(2);
            }
        }

        delete flights[_flightKey].insurees;
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function withdraw(address passengerAddress) 
        external 
        requireAuthorizedAppContract
        requireInsuredPassenger(passengerAddress)
        returns (uint256)
    {
        uint256 withdrawAmount = passengers[passengerAddress].credit;
        passengers[passengerAddress].credit = 0;
        totalFund = totalFund.sub(withdrawAmount);
        if (withdrawAmount > 0) {
            passengerAddress.transfer(withdrawAmount);
        }
        return withdrawAmount;
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund() public payable { totalFund = totalFund.add(msg.value); }

    function getFlightKey(
        address airline,
        string flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function authorizeCaller(
        address appContract
    ) external requireContractOwner {
        authorizedAppContracts[appContract] = 1;
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
        fund();
    }
}
