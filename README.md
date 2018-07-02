Bethereum Bounty Bet
===================================

Bet with your points from Bethereum Bounty program.

Every match has his own deployed smart contract with specific API link to get match results.

Smart Contract workflow:

**BountyBetFactory.sol**

1. constructor **BountyBetFactory()**
    - no specific parameters required

2. creating BountyUserBet smart contract for specific game **create()**
    - required parameters are:
        - **_minBuyIn** minimum buyIn for deployed game
        - **_apiUrlInputBase** base API URL with user auth token from provider
        - **_apiUrlInputHome** JSON path to home results
        - **_apiUrlInputAway** JSON path to away results
        - required API parameters below are shown in BountyBet.sol as an example


**BountyUserBet.sol**

1. constructor **BountyUserBet()**
    - SC is created from **BountyBetFactory.sol** with parameters below in section 2.

2. Pushing user tip into SC - **setDataInBet()**
    - function is saving user ID's with user's tip into SC
    - data are pushed from web3 front-end in batches (max 30 items in one array), once transaction is complete, then another is send with another data
    - clearing of this data is working every 5 minutes as cron on Node.js server

3. Once user ID's and tips are on SC, you can call **getAllBets()** to show all user ID's with tips
    - just before the start of match this Bet is closed on front-end so no new data are send to SC

4. When the match ended, function **getDataFromAPI()** call for API data
    - when calling this function, SC need to consist some ETH as balance for "oraclize fees"
    - you can't parse JSON in Solidity (or can you?) so you need to call each data separately
    - average time for waiting to get all data you need from API is 3 minutes, so if you're waiting long time, check Events on Etherescan

5. Once you get all data from API, you can call **setWinners()**
    - function will iterate all SC data and check for correct user tip
    - pot from game is divided with number of winners and every winner get exact number of points from pot

6. When SC check winners, you can call **showWinners()** to show winner user ID's with points
    - this information is send to bounty system, which check the user ID's and add new points to their bounty balance

Who's paying for the gas?
- on node.js server we are creating raw transaction with Web3 to send data to SC. Data are send in batches (max 30 items in one array), once transaction is complete, then another is send with another data.
- every transaction is signed with our private key