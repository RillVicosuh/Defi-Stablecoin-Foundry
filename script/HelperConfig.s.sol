//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wEthUsdPriceFeed;
        address wBtcUsdPriceFeed;
        address wEth;
        address wBtc;
        uint256 deployerKey;
    }

    //The variables below will be used for the Mock Aggregator so that we can have a mimick of a price feed when testing on a local chain
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    //This is the private key of the first default wallet that anvil gives when you run the local blockchain
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthCongfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthCongfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wEthUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wBtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wEth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wBtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    //Need to use a Mock when working on a local chain becuase there is no price feed like on testnets and mainnets
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wEthUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator mockEthUsdPriceFeed = new MockV3Aggregator( DECIMALS, ETH_USD_PRICE);
        ERC20Mock mockWEth = new ERC20Mock("WETH", "WETH", msg.sender, 100e18);
        MockV3Aggregator mockBtcUsdPriceFeed = new MockV3Aggregator( DECIMALS, ETH_USD_PRICE);
        ERC20Mock mockWBtc = new ERC20Mock("WETH", "WETH", msg.sender, 100e18);
        vm.stopBroadcast();

        return NetworkConfig({
            wEthUsdPriceFeed: address(mockEthUsdPriceFeed), // ETH / USD
            wEth: address(mockWEth),
            wBtcUsdPriceFeed: address(mockBtcUsdPriceFeed),
            wBtc: address(mockWBtc),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
