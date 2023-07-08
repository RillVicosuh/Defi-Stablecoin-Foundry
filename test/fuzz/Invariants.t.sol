//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeploySC} from "../../script/DeploySC.s.sol";
import {decentralizedStableCoin} from "../../src/decentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeploySC deployer;
    decentralizedStableCoin sc;
    DSCEngine logicEngine;
    HelperConfig config;
    Handler handler;
    address wEth;
    address wBtc;

    function setUp() external {
        deployer = new DeploySC();
        (sc, logicEngine, config) = deployer.run();
        (,, wEth, wBtc,) = config.activeNetworkConfig();
        //This indicates what contract we'll run the invariant tests on
        //targetContract(address(sc));
        handler = new Handler(logicEngine, sc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreCollateralThanStableCoin() public view {
        uint256 totalSCSupply = sc.totalSupply();
        uint256 totalWEthDeposited = IERC20(wEth).balanceOf(address(logicEngine));
        uint256 totalWBtcDeposited = IERC20(wEth).balanceOf(address(logicEngine));
        uint256 wEthValue = logicEngine.getUSDValue(wEth, totalWEthDeposited);
        uint256 wBtcValue = logicEngine.getUSDValue(wBtc, totalWBtcDeposited);

        assert(wEthValue + wBtcValue >= totalSCSupply);
    }
}
