//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//Run with --> make deploy ARGS="--network sepolia"

import {Script} from "forge-std/Script.sol";
import {decentralizedStableCoin} from "../src/decentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

//This script will deploy the stable coin contract itself and the logic/engine contract for the stable coin
contract DeploySC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (decentralizedStableCoin, DSCEngine, HelperConfig) {
        //creating a HelperConfig object to access the necessary infor for deploying the contracts
        HelperConfig config = new HelperConfig();

        //retrieving the info from the HelperConfig.s.sol file
        (address wEthUsdPriceFeed, address wBtcUsdPriceFeed, address wEth, address wBtc, uint256 deployerKey) =
            config.activeNetworkConfig();

        //Plugging in addresses into the array that need to be passed to the contructor for the DSCEngine contract
        tokenAddresses = [wEth, wBtc];
        priceFeedAddresses = [wEthUsdPriceFeed, wBtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        //Creating new decentralizedStableCoin contract
        decentralizedStableCoin sc = new decentralizedStableCoin();
        //Creating new DSCEngin contract and passing array of addresses and the address of the decentralizedStaleCoin contract
        DSCEngine logicEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(sc));

        //Transfering the ownership of the decentralizedStableCoin contract to the DSCEngin contract
        sc.transferOwnership(address(logicEngine));
        vm.stopBroadcast();
        return (sc, logicEngine, config);
    }
}
