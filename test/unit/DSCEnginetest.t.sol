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
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";
import {Test, console} from "forge-std/Test.sol";

contract DSCEngineTest is Test {
    DeploySC deployer;
    decentralizedStableCoin sc;
    DSCEngine logicEngine;
    HelperConfig config;
    address wEthUsdPriceFeed;
    address wBtcUsdPriceFeed;
    address wEth;
    address wBtc;
    uint256 deployerKey;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant COLLATERAL_TO_COVER = 20 ether;
    uint256 public constant MINT_AMOUNT = 100 ether;
    uint256 public STARTING_USER_BALANCE = 100 ether;

    //This setup function runs before every test
    function setUp() public {
        deployer = new DeploySC();
        (sc, logicEngine, config) = deployer.run();
        (wEthUsdPriceFeed, wBtcUsdPriceFeed, wEth, wBtc, deployerKey) = config.activeNetworkConfig();

        //Minting 100 WETH AND WBTC to the USER address for testing if the we are using a local blockchain
        if (block.chainid == 31337) {
            vm.deal(USER, STARTING_USER_BALANCE);
        }
        ERC20Mock(wEth).mint(USER, STARTING_USER_BALANCE);
        ERC20Mock(wBtc).mint(USER, STARTING_USER_BALANCE);
    }

    /*
     * Constructor Tests ****
     */

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    //This test function ensures that constructor only takes to address arrays of the same length
    function testRevertsIfTokenLengthDoesntMatchPriceFeed() public {
        //The constructor takes an array of token addresses and price feed addresses
        //The two arrays need to be the same length
        tokenAddresses.push(wEth);
        priceFeedAddresses.push(wEthUsdPriceFeed);
        priceFeedAddresses.push(wBtcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAndPriceFeedAddressDiscrepancy.selector); //This is the specific error we expect
        //I expect the following line to revert because two addresses of different length are being passed to the constructor
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(sc));
    }

    /*
     * Price Tests ****
     */

    //This test function ensures that the getUsdValue function works properly, giving the usd value of a certain amount of eth or btc
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18; //15 WETH
        //This test will be run on the anvil local blockchain, so it will use an ETH value of $2000/ETH
        //SO, 15e18 * 2000/ETH = 30000e18  or $30,000
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = logicEngine.getUSDValue(wEth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    //This test function ensure that the getTokenAmountFromUsd function works properly, giving the token value, in this case eth, of a certain amount of usd
    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectWEth = 0.05 ether;
        uint256 actualWEth = logicEngine.getTokenAmountFromUsd(wEth, usdAmount);
        //Expected WETh and the acutal calculated WEth using the getTokenAmountFromUsd function are identical
        assertEq(expectWEth, actualWEth);
    }

    /*
     * depositCollateral Tests ****
     */

    //This test function ensures that if a user tries to deposit 0 collateral, it reverts
    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(wEth).approve(address(logicEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        //I expect the following line to be reverted because the collateral amount a user deposits cannot be 0
        logicEngine.depositCollateral(wEth, 0);
        vm.stopPrank();
    }

    //This test function ensures that user cannot try to deposit an unallowed token as collateral
    function testRevertIfTokenIsNotAllowed() public {
        //Creating a random token with the ERC20Mock contract
        ERC20Mock randomToken = new ERC20Mock("RANDO", "RANDO", USER, COLLATERAL_AMOUNT);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        //We are using a random token with a random address and not WETH or WBTC, so it should revert
        logicEngine.depositCollateral(address(randomToken), COLLATERAL_AMOUNT);
        vm.stopPrank;
    }

    //This is a modifier that can be added to a test function to deposit collateral before the execution of the function
    modifier collateralDeposited() {
        vm.startPrank(USER);
        ERC20Mock(wEth).approve(address(logicEngine), COLLATERAL_AMOUNT);
        logicEngine.depositCollateral(wEth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    //This test function checks to see if we can first deposit collateral and then get the account info, which include the amount of stable coin minted and the total collateral value in WETH
    function testCanDepositCollateralAndGetAccountInfo() public collateralDeposited {
        //After depositing collateral, get the users info
        (uint256 totalSCMinted, uint256 collateralUsdValue) = logicEngine.getAccountInfo(USER);
        uint256 expectedTotalSCMinted = 0;
        uint256 expectedWEthAmount = logicEngine.getTokenAmountFromUsd(wEth, collateralUsdValue);
        //Both should be 0 because no stable coin was minted
        assertEq(totalSCMinted, expectedTotalSCMinted);
        //Both should be 10 ether
        assertEq(COLLATERAL_AMOUNT, expectedWEthAmount);
    }

    /*
     * Liquidation Tests ****
     */
    modifier liquidated() {
        vm.startPrank(USER);
        //Approving collateral and depositing it, then minting stable coin
        ERC20Mock(wEth).approve(address(logicEngine), COLLATERAL_AMOUNT);
        logicEngine.depositCollateralAndMintStableCoin(wEth, COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        //Changing the price of ETH to $18 so that we can liquidate
        int256 wEthUsdUpdatedPrice = 18e8;
        MockV3Aggregator(wEthUsdPriceFeed).updateAnswer(wEthUsdUpdatedPrice);
        //Get health factor after changing eth price
        uint256 userHealthFactor = logicEngine.getHealthFactor(USER);

        ERC20Mock(wEth).mint(LIQUIDATOR, COLLATERAL_TO_COVER);
        vm.startPrank(LIQUIDATOR);
        console.log("working");
        ERC20Mock(wEth).approve(address(logicEngine), COLLATERAL_TO_COVER);
        //Depositing 20 ether of collateral and minting 10 ether worth of stable coin
        logicEngine.depositCollateralAndMintStableCoin(wEth, COLLATERAL_TO_COVER, MINT_AMOUNT);
        sc.approve(address(logicEngine), MINT_AMOUNT);
        logicEngine.liquidate(wEth, USER, MINT_AMOUNT);
        _;
    }

    function testliquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(wEth).balanceOf(LIQUIDATOR);
        uint256 expectedWEth = logicEngine.getTokenAmountFromUsd(wEth, MINT_AMOUNT)
            + (logicEngine.getTokenAmountFromUsd(wEth, MINT_AMOUNT) / logicEngine.getLiquidationBonus());
        console.log("liquidatorWethBalance: %s", liquidatorWethBalance);
        console.log("expectedWEth: %s", expectedWEth);
        assertEq(liquidatorWethBalance, expectedWEth);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorSCMinted,) = logicEngine.getAccountInfo(LIQUIDATOR);
        assertEq(liquidatorSCMinted, MINT_AMOUNT);
    }

    //This test function ensures that a user does not have any stable coin left after being liquidated
    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userSCMinted,) = logicEngine.getAccountInfo(USER);
        assertEq(userSCMinted, 0);
    }

    /*
     * View Tests ****
     */

    //This test function ensures the the stable coin address can be returned
    function testGetStableCoinAddress() public {
        address scAddress = logicEngine.getStableCoinContract();
        assertEq(address(sc), scAddress);
    }
    //This test function ensures that the price feed address can be retrieved

    function testGetCollateralTokenPriceFeed() public {
        address priceFeed = logicEngine.getCollateralTokenPriceFeed(wEth);
        assertEq(priceFeed, wEthUsdPriceFeed);
    }
}
