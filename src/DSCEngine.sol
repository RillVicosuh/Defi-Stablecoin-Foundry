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
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //This means you need to be over 200% collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;

    /*
     * Events ****
     */
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

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

    function depositCollateralAndMintStableCoin(address tokenCollateralAddress, uint256 collateralAmount)
        external
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

    function depositCollateral() external {}

    function redeemCollateralForStableCoin() external {}

    //This will be can be used after collateral has been deposited
    //If a user has 100 in WETH deposited as collateral, they can only mint 75 stable coins for $75 or whatever depending on the threshold
    function mintStableCoin(uint256 scMintAmount) external greaterThanZero(scMintAmount) {
        //mapping the amount of stable coin minted to the user that is minting
        s_SCMinted[msg.sender] += scMintAmount;
    }

    function burnStableCoin() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    /*
     * Private and Internal View Functions ****
     */

    //This function return the total amount of stable coins minted and the value of the collateral the user has, in USD
    function _getAccountInfo(address user) private view returns (uint256 totalSCMinted, uint256 collateralUSDValue) {
        totalSCMinted = s_SCMinted[user]; //Using the mapping that maps the user to the amount of stable coins they minted
        //Getting the value of the collateral in USD by using the getAccountCollateralValue function
        collateralUSDValue = getAccountCollateralValue(user);
    }

    //This function will return how close to liquidation a user is
    //If the user goes below a health factor of 1, they can get liquidated
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalSCMinted, uint256 collateralUSDValue) = _getAccountInfo(user);
        uint256 collateralAdjustedForThreshold = (collateralUSDValue * LIQUIDATION_THRESHOLD) / 100;
    }

    //This function checks if the health factor is broken and reverts if it is
    function _IsHealthFactorBroken(address user) internal {}

    /*
     * Public and Enternal View Functions ****
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
    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        //Getting the chainlink price feed of the collateral token using the mapping of the price feed address to the token address
        //The price feed address needs to be for ETH/USD and BTC/USD
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        //Calling the latestRoundData function using the price feed object and only getting the price return variable
        (, int256 price,,,) = priceFeed.latestRoundData(); //Currently ETH is $1950 and it would return 1950 * 1e18 (the gwei amount)
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
