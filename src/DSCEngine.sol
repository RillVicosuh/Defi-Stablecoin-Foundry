//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {decentralizedStableCoin} from "./decentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol"; //Allows us to use the reentrancy modifier

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
    /**** Errors *****/

    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAndPriceFeedAddressDiscrepancy();
    error DSCEngine__TokenNotAllowed();

    /**** State Variables *****/

    mapping(address token => address priceFeed) private s_priceFeeds;
    //The user address is mapped to a mapping of the token they are using as collateral and the amount of the collateral
    mapping(address user => mapping(address token => uint256 amount))
        private s_collaterDeposited;
    decentralizedStableCoin immutable i_dsc;

    /**** Events *****/
    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    /**** Modifiers *****/

    //Modifier to ensure the token trying to be used as collateral is either WETh orWBTC
    modifier isTokenAllowd(address token) {
        //Checks to see if the token address in mapped in the s_priceFeeds mapping
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
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscContractAddress
    ) {
        //Amount of token addresses and price feed addresses should be the same
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAndPriceFeedAddressDiscrepancy();
        }
        //Mapping token addresses to price feed addresses
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        i_dsc = decentralizedStableCoin(dscContractAddress);
    }

    /**** External Functions *****/

    function depositCollateralAndMintStableCoin(
        address tokenCollateralAddress,
        uint256 collateralAmount
    )
        external
        greaterThanZero(collateralAmount)
        isTokenAllowd(tokenCollateralAddress)
        nonReentrant
    {
        s_collaterDeposited[msg.sender][
            tokenCollateralAddress
        ] += collateralAmount;
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            collateralAmount
        );
    }

    function depositCollateral() external {}

    function redeemCollateralForStableCoin() external {}

    function burnStableCoin() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
