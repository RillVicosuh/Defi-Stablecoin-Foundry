//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

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

contract DSCEngine {
    function depositCollateralAndMintStableCoin() external {}

    function depositCollateral() external {}

    function redeemCollateralForStableCoin() external {}

    function burnStableCoin() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
