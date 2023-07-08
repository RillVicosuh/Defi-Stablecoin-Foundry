//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {decentralizedStableCoin} from "./decentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol"; //Allows us to use the reentrancy modifier
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
    @title DSCEngine
    @author Ricardo Villcana

    For this stablecoin we want to maintain a 1 token = 1 dollar peg

    Stable Coin Attributes:
        Collateral: Exogenous (Eth & Btc)
        Minting: Algorithmic
        Relative Stability: Pegged to USD

    -This stable coin is similar to DAI if DAI had absolutely no guidance and was purely algorithmic. It also has no fees and only backed by WETH and WBTC.
    -With this decentralized stable coin system, it should at no point be overcollateralized. The value of all the collateral should never be less
     than the total value of all the stable coins in circulation.
    -This contract will be the core of the decentralized stable coin system that holds the logic for minting and redeeming the stablecoin, as well as,
     depositing and withdrawing the collateral.
*/

contract DSCEngine is ReentrancyGuard {
    /*
     * Errors ****
     */

    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAndPriceFeedAddressDiscrepancy();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__FailedTransfer();
    error DSCEngine__HealthFactorBroken(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorGood();
    error DSCEngine__HealthFactorNotImproved();

    /*
     * State Variables ****
     */

    mapping(address token => address priceFeed) private s_priceFeeds;
    //The user address is mapped to a mapping of the token they are using as collateral and the amount of the collateral
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 scMintedAmount) private s_SCMinted;
    decentralizedStableCoin immutable i_dsc;
    address[] private s_collateralTokens; //An array that holds the addresses of the tokens that can be used as collateral
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //This means you need to be over 200% collateralized or double the collateral then you havd stablecoins.
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant HEALTH_FACTOR_MIN = 1e18; //Minimum health factor score allowed before liquidation
    uint256 private constant LIQUIDATION_BONUS = 10; //A 10% bonus for liquidating

    /*
     * Events ****
     */
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    /*
     * Modifiers ****
     */

    //Modifier to ensure the token trying to be used as collateral is either WETh orWBTC
    modifier isTokenAllowd(address token) {
        //Checks to see if the token address is mapped in the s_priceFeeds mapping
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    //Modifier to ensure the any amount of stable coins or collateral we are dealing with is more than zero
    modifier greaterThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    //The constructor will take in an array of token addresses, in this case, WETH and WBTC
    //The constructor also takes in an array of chainlink price feed addresses of those tokens so that we know the current price of ETH and BTC to determine the value of the collateral at any time
    //The token addresses will be mapped to the price feed addresses in the s_priceFeeds mapping, so that we know which token are allowed
    //Then finally, the constructor takes in the stable coin contract address so that we can access the mint and burn functions for the stable coin
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscContractAddress) {
        //Amount of token addresses and price feed addresses should be the same
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAndPriceFeedAddressDiscrepancy();
        }
        //Mapping token addresses to price feed addresses
        //Also adding the token addresses to the array of the collateral token addresses
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = decentralizedStableCoin(dscContractAddress);
    }

    /*
     * External Functions ****
     */

    //This function deposits collateral and minte the stable coins in one transaction
    function depositCollateralAndMintStableCoin(
        address tokenCollateralAddress,
        uint256 collateralAmount,
        uint256 scMintAmount
    ) external {
        depositCollateral(tokenCollateralAddress, collateralAmount);
        mintStableCoin(scMintAmount);
    }

    //This function burns stable coins and redeems collateral in one transaction
    function redeemCollateralForStableCoin(
        address tokenCollateralAddress,
        uint256 collateralAmount,
        uint256 scBurnAmount
    ) external {
        burnStableCoin(scBurnAmount);
        redeemCollateral(tokenCollateralAddress, collateralAmount);
    }

    //This function allows a user to take out their collateral
    //The health factor must remain above 1 after the collateral is redeemed, or else the transaction will be reverted
    function redeemCollateral(address tokenCollateralAddress, uint256 collateralAmount)
        public
        greaterThanZero(collateralAmount)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, collateralAmount, msg.sender, msg.sender);
        //Need to check if health factor is still 1 after removing collateral
        _IsHealthFactorBroken(msg.sender);
    }

    //This function allows a user to liquidate another user if their healthfactor has gone below 1.
    /*
        - A user can be partially liquidated
        - Users will be incentivized with a liquidation bonus to liquidate another user
        - The protocol should be about 200% overcollateralized for it to work
        - If the protocol were 100% collateralized, there would be no liquidation bonus/incentive for users
    */
    function liquidate(address tokenCollateralAddress, address user, uint256 debtToCover)
        external
        greaterThanZero(debtToCover)
        nonReentrant
    {
        //Ensuring health factor is actually below 1 in order for them to be liquidated
        uint256 initialUserHealthFactor = _healthFactor(user);
        if (initialUserHealthFactor >= HEALTH_FACTOR_MIN) {
            revert DSCEngine__HealthFactorGood();
        }

        //Converting the amount of debt to be covered, lets say $50, into a token amount, either ETH or BTC
        //EX: User to be liquidated: $150 ETH, $110 stable coin
        //    debtToCover: $110
        //    $110 of stable coin == 0.055 ETH if ETH is $2000
        uint256 debtCoveredConvertedToToken = getTokenAmountFromUsd(tokenCollateralAddress, debtToCover);
        //If debtToCover is $110 or 0.055 ETH, then the bonus will be (0.055 * 10)/ 100 = 0.0055 ETH as a bonus for liquidating
        uint256 collateralBonus = (debtCoveredConvertedToToken * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        //This will be the total amount in ETH or BTC that the user will recieve, which is the amount they covered + the bonus for liquidating
        //In the example case: 0.05ETH + 0.0055ETH = 0.0555ETH that they will recieve
        uint256 collateralToRedeem = debtCoveredConvertedToToken + collateralBonus;
        //The user who liquidates will receive the collateralToRedeem from the user that is being liqiudated
        _redeemCollateral(tokenCollateralAddress, collateralToRedeem, user, msg.sender);
        //Finally, we need to burn the stable coin that the liquidator covered to
        _burnStableCoin(debtToCover, user, msg.sender);

        //If the health factor of the user being liquidated did not improve, then revert
        uint256 updatedUserHealthFactor = _healthFactor(user);
        if (updatedUserHealthFactor <= initialUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        //We also want to check that the health factor of the liquidator did not go below 1
        _IsHealthFactorBroken(msg.sender);
    }

    /*
     * Public Functions ****
     */
    function depositCollateral(address tokenCollateralAddress, uint256 collateralAmount)
        public
        greaterThanZero(collateralAmount)
        isTokenAllowd(tokenCollateralAddress)
        nonReentrant
    {
        //Mapping the amount of collateral to the specific tokem address of that token(ETH of BTC), then mapping that mapping to the address of the user depositing the collateral
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += collateralAmount;
        //Emmitting an event after the collater has been deposited
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, collateralAmount);
        //Actually transfering the collateral on the blockchain from the user to this contract address
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) {
            revert DSCEngine__FailedTransfer();
        }
    }

    //This will be can be used after collateral has been deposited
    //If a user has 100 in WETH deposited as collateral, they can only mint 75 stable coins for $75 or whatever depending on the threshold
    function mintStableCoin(uint256 scMintAmount) public greaterThanZero(scMintAmount) nonReentrant {
        //mapping the amount of stable coin minted to the user that is minting
        s_SCMinted[msg.sender] += scMintAmount;
        _IsHealthFactorBroken(msg.sender);
        //Actually minting the stable coins
        //Using the mint function from the decentralizedStableCoin contract
        bool minted = i_dsc.mint(msg.sender, scMintAmount);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnStableCoin(uint256 amount) public greaterThanZero(amount) {
        _burnStableCoin(amount, msg.sender, msg.sender);
        //We don't really need to check, but doesn't hurt to be safe
        _IsHealthFactorBroken(msg.sender);
    }

    /*
     * Private Functions ****
     */

    /*
     * Private and Internal View Functions ****
     */

    function _burnStableCoin(uint256 scBurnAmount, address onBehalfOf, address stableCoinFrom) private {
        s_SCMinted[onBehalfOf] -= scBurnAmount;
        //Transfering from the users address to the decentralized stable coin address
        bool success = i_dsc.transferFrom(stableCoinFrom, address(this), scBurnAmount);
        if (!success) {
            revert DSCEngine__FailedTransfer();
        }
        //burning the amount of stable coin that was transfered
        i_dsc.burn(scBurnAmount);
    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 collateralAmount, address from, address to)
        private
    {
        //Removing the amount of collateral the user has in this contract
        s_collateralDeposited[from][tokenCollateralAddress] -= collateralAmount;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, collateralAmount);
        //Transfering the collateral to the user
        bool success = IERC20(tokenCollateralAddress).transfer(to, collateralAmount);
        if (!success) {
            revert DSCEngine__FailedTransfer();
        }
    }

    //This function return the total amount of stable coins minted and the value of the collateral the user has, in USD
    function _getAccountInfo(address user) private view returns (uint256 totalSCMinted, uint256 collateralUSDValue) {
        totalSCMinted = s_SCMinted[user]; //Using the mapping that maps the user to the amount of stable coins they minted
        //Getting the value of the collateral in USD by using the getAccountCollateralValue function
        collateralUSDValue = getAccountCollateralValue(user);
    }

    //This function will return how close to liquidation a user is
    //If the user goes below a health factor of 1, they can get liquidated
    //Having 500 stable coins mean you must have atleast $1000 in eth or btc. If the value of the collateral goes below that, you can get liquidated
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalSCMinted, uint256 collateralUSDValue) = _getAccountInfo(user);
        uint256 collateralAdjustedForThreshold = (collateralUSDValue * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        //EX: $1000 ETH / 100 stablecoins
        //1000 * 50 = 50000 / 100 = (500 / 100)  <---This is what's returned
        return (collateralAdjustedForThreshold * PRECISION) / totalSCMinted; //If less than one, can get liquidated
    }

    //This function checks if the health factor is broken and reverts if it is
    function _IsHealthFactorBroken(address user) internal view {
        uint256 healthFactorScore = _healthFactor(user);
        if (healthFactorScore < HEALTH_FACTOR_MIN) {
            revert DSCEngine__HealthFactorBroken(healthFactorScore);
        }
    }

    /*
     * Public and Internal View Functions ****
     */

    //Given a users address, this function gets the tokens they deposited as collateral and the amount, then calculates the USD value of the collateral using the getUSDValue function
    function getAccountCollateralValue(address user) public view returns (uint256) {
        uint256 totalCollateralUSDValue;
        //Loops through each collateral token this contract can handle and determines how much of each collateral token the user has
        //It then calculates the total USD value of the collateral token. For example if they have 0.2 WETH, then the total value in USD is 400
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralUSDValue += getUSDValue(token, amount);
        }
        return totalCollateralUSDValue;
    }

    //This function uses the ChainLink price feed using the AggregatorV3Interface to calculate a give token and its amount into a USD value
    function getUSDValue(address tokenAddress, uint256 amount) public view returns (uint256) {
        //Getting the chainlink price feed of the collateral token using the mapping of the price feed address to the token address
        //The price feed address needs to be for ETH/USD and BTC/USD
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[tokenAddress]);
        //Calling the latestRoundData function using the price feed object and only getting the price return variable
        (, int256 price,,,) = priceFeed.latestRoundData(); //Currently ETH is $1950 and it would return 1950 * 1e18 (the gwei amount)
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    /*
     * Public and External View Functions ****
     */

    function getTokenAmountFromUsd(address tokenAddress, uint256 usdAmountInWei) public view returns (uint256) {
        //Uisng the AggregatorV3Interface to get the current price of either ETH or BTC
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[tokenAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        //If if the usd amount is $10 it would look like...
        //($10e18 * 1e18 / ($2000e8 * 1e10))  <--- This is what's returned
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getAccountInfo(address user) external view returns (uint256 totalSCMinted, uint256 collaterUsdValue) {
        (totalSCMinted, collaterUsdValue) = _getAccountInfo(user);
    }

    function getHealthFactor() external view {}
}
