pragma solidity ^0.4.18;

import "./Factory.sol";
import "./BountyUserBet.sol";

contract BountyBetFactory is Factory {
    address public creator;
    uint256 feeGasAmount = 1000000000000000;// for Oraclize fees

    modifier onlyCreator {
        require(msg.sender == creator);
        _;
    }

    function BountyBetFactory() {
        creator = msg.sender;
    }
    
    function() payable public {}

    /**
      * @dev Creates new instance of BounyUserBet and register new address of this instance
      * @param _minBuyIn minimum buyIn for deployed game
      * @param _apiUrlInputBase base API URL with user auth token from provider
      * @param _apiUrlInputHome JSON path to home results
      * @param _apiUrlInputAway JSON path to away results
    */
    function create(uint256 _minBuyIn, string _apiUrlInputBase, string _apiUrlInputHome, string _apiUrlInputAway) public onlyCreator returns (address betTicket)
    {
        betTicket = new BountyUserBet(_minBuyIn, _apiUrlInputBase, _apiUrlInputHome, _apiUrlInputAway, creator);
        register(betTicket);
        feeGas(betTicket);
    }

    /**
      * @dev Send ETH from contract balance on new instantiation (required to pay for API calls)
      * @param _newInstantiation address of new BountyUserBet instantiation
    */
    function feeGas(address _newInstantiation) internal {
        if(this.balance > feeGasAmount) {
            _newInstantiation.transfer(feeGasAmount);
        }
    }

    function getBalance() public constant returns(uint256) {
        return this.balance;
    }

    // callable by creator only
    function withdraw() onlyCreator public {
        creator.transfer(this.balance);
    }
}