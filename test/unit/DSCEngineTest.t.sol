//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DCSEngine.sol";

contract DSCEngineTest is Test{
    DeployDSC deployer;

    function setUp() public {
        deployer = new DeployDSC();
    }

}