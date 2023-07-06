//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//Run all test --> forge test
//Run certain test like --> forge test -m testGetUsdValue

import {Test} from "forge-std/Test.sol";
import {DeploySC} from "../../script/DeploySC.s.sol";
import {decentralizedStableCoin} from "../../src/decentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeploySC deployer;
    decentralizedStableCoin sc;
    DSCEngine logicEngine;
    HelperConfig config;
    address wEthUsdPriceFeed;
    address wEth;

    address public USER = makeAddr("user");
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;

    function setUp() public {
        deployer = new DeploySC();
        (sc, logicEngine, config) = deployer.run();
        (wEthUsdPriceFeed,, wEth,,) = config.activeNetworkConfig();
    }

    /*
     * Price Tests ****
     */

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18; //15 WETH
        //This test will be run on the anvil local blockchain, so it will use an ETH value of $2000/ETH
        //SO, 15e18 * 2000/ETH = 30000e18  or $30,000
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = logicEngine.getUSDValue(wEth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    /*
     * depositCollateral Tests ****
     */

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(wEth).approve(address(sc), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        sc.depositCollateral(wEth, 0);
        vm.stopPrank();
    }
}
