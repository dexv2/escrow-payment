// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {EscrowFactory} from "../src/EscrowFactory.sol";
import {HelperConfig} from "./HelperConfig.sol";

contract DeployFactory is Script {
    function run() public returns (EscrowFactory) {
        HelperConfig config = new HelperConfig();

        uint256 inconvenienceThreshold = 50;

        vm.startBroadcast(config.deployerKey());
        EscrowFactory factory = new EscrowFactory(config.getSupportedStablecoins(), inconvenienceThreshold);
        vm.stopBroadcast();

        return factory;
    }
}
