//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {decentralizedStableCoin} from "../../src/decentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine logicEngine;
    decentralizedStableCoin sc;

    ERC20Mock wEth;
    ERC20Mock wBtc;
    MockV3Aggregator wEthUsdPriceFeed;

    //We are assigning the largest number that can be stored in a uint96 variable, which is large, but not as large as uint256
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    //That handler will take in the contracts that'll be handled
    constructor(DSCEngine _logicEngine, decentralizedStableCoin _sc) {
        //Getting contract objects
        logicEngine = _logicEngine;
        sc = _sc;

        address[] memory collateralTokens = logicEngine.getCollateralTokens();
        wEth = ERC20Mock(collateralTokens[0]);
        wBtc = ERC20Mock(collateralTokens[1]);

        wEthUsdPriceFeed = MockV3Aggregator(logicEngine.getCollateralTokenPriceFeed(address(wEth)));
    }

    //This invariant test will help test the mintStableCoin function with random stable coin mint amounts and random accounts with different amounts of collateral
    function mintStableCoin(uint256 scMintAmount) public {
        (uint256 totalSCMinted, uint256 collateralUsdVaue) = logicEngine.getAccountInfo(msg.sender);
        int256 maxSCToMint = (int256(collateralUsdVaue) / 2) - int256(totalSCMinted);
        if (maxSCToMint < 0) {
            return;
        }
        //Making sure the amount of stable coin to mint is limited from 1 to the max amount stable coin they can mint
        scMintAmount = bound(scMintAmount, 1, uint256(maxSCToMint));
        //Do not mint if the amount of stable coin that can be minted is 0
        if (scMintAmount == 0) {
            return;
        }

        vm.startPrank(msg.sender);
        logicEngine.mintStableCoin(scMintAmount);
        vm.stopPrank();
    }

    //This invariant test will help test the depositCollateral function with random numbers for collateralSeed and collateralAmount
    function depositCollateral(uint256 collateralSeed, uint256 collateralAmount) public {
        //Using _getCollaterAddressFromSeed to get either WETH or WBTC address
        ERC20Mock collateralToken = _getCollateralAddressFromSeed(collateralSeed);
        //Limit the random number assigned to collateralAmount to a number between 1 and MAX_DEPOSIT_SIZE
        collateralAmount = bound(collateralAmount, 1, MAX_DEPOSIT_SIZE);

        //Before we deposit the collateral, for this test, we need to make sure the address has enough collateral
        vm.startPrank(msg.sender);
        collateralToken.mint(msg.sender, collateralAmount);
        collateralToken.approve(address(logicEngine), collateralAmount);
        logicEngine.depositCollateral(address(collateralToken), collateralAmount);
        vm.stopPrank();
    }

    //This invariant test will help test the redeemCollateral function with random values of collateral seeds and amounts of collateral to redeem
    function redeemCollateral(uint256 collateralSeed, uint256 collateralAmount) public {
        //Gets a token address, WETH or WBTC, from the collateral seed
        ERC20Mock collateralToken = _getCollateralAddressFromSeed(collateralSeed);
        uint256 collateralToRedeem = logicEngine.getAccountCollateralBalance(address(collateralToken), msg.sender);
        //Limit the amount of collateral the user wants to redeem from 1 to the amount of collateral they have deposited in their account
        collateralAmount = bound(collateralAmount, 0, collateralToRedeem);
        //Some of the random runs will have an account with 0 collateral to redeem
        //The function should return and not call redeemCollateral if the account does not have any collateral to redeem
        if (collateralAmount == 0) {
            return;
        }
        logicEngine.redeemCollateral(address(collateralToken), collateralAmount);
    }

    //This breaks the invariant that system should always be overcollateralized
    //This function allows the Mock WETH price to be updated to different values
    /*function updateCollateralTokenPrice(uint96 updatedPrice) public {
        int256 updatedPriceInt = int256(uint256(updatedPrice));
        wEthUsdPriceFeed.updateAnswer(updatedPriceInt);
    }*/

    //This function will be used in the test function above to ensure that we will always test the depositCollateral function with a valid token address
    function _getCollateralAddressFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        //If the seed is 0, 2, 4, 6 (even), then the collateral token we are dealing with is WETH
        if (collateralSeed % 2 == 0) {
            return wEth;
        }
        return wBtc;
    }
}
