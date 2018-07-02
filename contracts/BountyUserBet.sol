pragma solidity ^0.4.18;

import "./libs/SafeMath.sol";
import "./libs/Strings.sol";
import "./libs/oraclizeAPI_05.sol";

contract BountyUserBet is usingOraclize {

    using SafeMath for uint256;
    using strings for *;

    address public owner;

    uint256 public pot;
    uint256 winPot;
    uint256 numUserBets;
    uint256 numWinners;

    string public match_status;
    string public match_home_score;
    string public match_away_score;
    string public api_url;
    string public api_url_input_base;
    string public api_url_input_match_status;
    string public api_url_input_home;
    string public api_url_input_away;

    uint public reqKey;

    uint256 rule_for_home;
    uint256 rule_for_away;
    uint256 rule_for_draw;

    uint256[] public userIDs;
    uint256[] public userTips;

    mapping (uint => UserBet) userBets;
    mapping (uint => Winner) winners;
    mapping (bytes32 => Request) requests;

    event newOraclizeQuery(string descPartOne, string descPartTwo, string descPartThree);
    event newAPIResult(string result);

    enum Phase {
    CheckHomeScore,
    CheckAwayScore
    }

    Phase public currentPhase = Phase.CheckHomeScore;

    struct UserBet {
    uint256 userID;
    uint256 userTip;
    }

    struct Winner {
    uint256 winID;
    uint256 winPoints;
    }

    struct Request {
    bool initialized;
    bool processed;
    uint key;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function() payable public {}

    /**
      * @dev Constructor of new Bounty game
      * @param _minBuyIn minimum buyIn for deployed game
      * @param _apiUrlInputBase base API URL with user auth token from provider
      * @param _apiUrlInputHome JSON path to home results
      * @param _apiUrlInputAway JSON path to away results
    */
    function BountyUserBet
    (
        uint256 _minBuyIn,
        string _api_url_input_base,
        string _api_url_input_home,
        string _api_url_input_away,
        address _creator
    ) {
        owner = _creator;
        winPot = _minBuyIn;
        api_url_input_base = _api_url_input_base;
        api_url_input_home = _api_url_input_home;
        api_url_input_away = _api_url_input_away;
        reqKey = 0;
        numUserBets = 0;
        rule_for_home = 0;
        rule_for_away = 1;
        rule_for_draw = 2;
    }

    function __callback(bytes32 myid, string result) {
        require(msg.sender == oraclize_cbAddress());
        newAPIResult(result);

        Request memory r = requests[myid];

        if (r.initialized && !r.processed) {
            if (currentPhase == Phase.CheckAwayScore) {
                match_away_score = result;
            } else {
                match_home_score = result;
                setApiDataPhase(Phase.CheckAwayScore);
                reqKey += reqKey++;
                update(api_url_input_away, reqKey);
            }
            requests[myid].processed = true;
        }

    }

    function getDataFromAPI() public onlyOwner payable {
        reqKey += reqKey++;
        update(api_url_input_home, reqKey);
    }

    /**
      * @dev Generating API call URL from constructor parameters
      * @param base URL of called API
      * @param jsonPath JSON path in returned JSON result from API
      * @return API URL as a string
    */
    function generateUrl(string base, string jsonPath) constant returns (string) {
        strings.slice[] memory parts = new strings.slice[](5);
        parts[0] = 'json('.toSlice();
        parts[1] = base.toSlice();
        parts[2] = ')'.toSlice();
        parts[3] = jsonPath.toSlice();
        return ''.toSlice().join(parts);
    }

    /**
      * @dev Calling API for a new data with new JSON path
      * @param _getData JSON path
      * @param key current API request key
      * @return new oraclize API call
    */
    function update(string _getData, uint key) payable {
        api_url =  generateUrl(api_url_input_base, _getData);
        bytes32 requestId = oraclize_query('URL', api_url, 500000);
        requests[requestId] = Request(true, false, key);
        newOraclizeQuery('Oraclize query for ',_getData,' was sent, standing by for the answer..');
    }

    /**
      * @dev Saving user ID's with user's tip into SC (pls check REAMDE file)
      * @param _userIDs Array of user ID's from Bounty system
      * @param _userTips Array of user tips
    */
    function setDataInBet(uint256[] _userIDs, uint256[] _userTips) public onlyOwner {
        userIDs = _userIDs;
        userTips = _userTips;

        for(uint256 i = 0; i < userIDs.length; i++) {
            userBets[numUserBets] = UserBet(userIDs[i], userTips[i]);
            numUserBets++;
            pot += winPot;
        }
    }

    //Returns all current bets saved in smart contract
    function getAllBets() public constant returns (uint256[], uint256[]) {

        uint256[] memory userIDs = new uint256[](numUserBets);
        uint256[] memory userTips = new uint256[](numUserBets);

        for (uint256 i = 0; i < numUserBets; i++) {
            userIDs[i] = userBets[i].userID;
            userTips[i] = userBets[i].userTip;
        }

        return (userIDs, userTips);

    }

    //Function will iterate through all SC data and check for correct user tip
    //Pot from game is divided with number of winners and every winner get exact
    //number of points from pot
    function setWinners() public onlyOwner {
        uint256 userWinID;
        uint parsedHomeScore = stringToUint(match_home_score);
        uint parsedAwayScore = stringToUint(match_away_score);

        for(uint256 i = 0;i < numUserBets;i++){
            if (parsedHomeScore > parsedAwayScore) {
                if (userBets[i].userTip == rule_for_home) {
                    userWinID = numWinners++;
                    winners[userWinID] = Winner(userBets[i].userID, 0);
                }
            } else if (parsedHomeScore == parsedAwayScore) {
                if (userBets[i].userTip == rule_for_draw) {
                    userWinID = numWinners++;
                    winners[userWinID] = Winner(userBets[i].userID, 0);
                }
            } else {
                if (userBets[i].userTip == rule_for_away) {
                    userWinID = numWinners++;
                    winners[userWinID] = Winner(userBets[i].userID, 0);
                }
            }
        }

        winPot = pot.div(numWinners);

        for (uint256 x = 0;x < numWinners;x++) {
            winners[x].winPoints = winPot;
        }
    }

    //Show winner user ID's with points
    function showWinners() public constant returns (uint256[], uint256[]) {
        uint256[] memory winnerID = new uint256[](numWinners);
        uint256[] memory winnerPrize = new uint256[](numWinners);

        for (uint256 i = 0; i < numWinners; i++) {
            winnerID[i] = winners[i].winID;
            winnerPrize[i] = winners[i].winPoints;
        }

        return (winnerID, winnerPrize);
    }

    /**
      * @dev Control function to prevent calling same API data many times
      * @param _nextPhase next phase of API call
    */
    function setApiDataPhase(Phase _nextPhase) internal {
        bool canSwitchPhase
        = (currentPhase == Phase.CheckHomeScore && _nextPhase == Phase.CheckAwayScore);

        require(canSwitchPhase);
        currentPhase = _nextPhase;
    }

    /**
      * @dev API is returning result as string. To correctly determine result we need to convert it into string
      * @param s string to uint
      * @return int
    */
    function stringToUint(string s) constant returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint i = 0; i < b.length; i++) { // c = b[i] was not needed
            if (b[i] >= 48 && b[i] <= 57) {
                result = result * 10 + (uint(b[i]) - 48); // bytes and int are not compatible with the operator -.
            }
        }
        return result; // this was missing
    }
}
