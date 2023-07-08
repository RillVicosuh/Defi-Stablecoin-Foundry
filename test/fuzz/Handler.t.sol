//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {decentralizedStableCoin} from "../../src/decentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    DSCEngine logicEngine;
    decentralizedStableCoin sc;

    ERC20Mock wEth;
    ERC20Mock wBtc;

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
    }

    //This invariant test will test the depositCollateral function with random numbers for collateralSeed and collateralAmount
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

    //This function will be used in the test function above to ensure that we will always test the depositCollateral function with a valid token address
    function _getCollateralAddressFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        //If the seed is 0, 2, 4, 6 (even), then the collateral token we are dealing with is WETH
        if (collateralSeed % 2 == 0) {
            return wEth;
        }
        return wBtc;
    }
}
