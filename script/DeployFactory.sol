// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {EscrowFactory} from "../src/EscrowFactory.sol";
import {PhilippinePeso} from "../src/PhilippinePeso.sol";

contract DeployFactory is Script {
    function run() public returns (EscrowFactory) {
        uint256 inconvenienceThreshold = 50;

        vm.startBroadcast();
        PhilippinePeso philippinePeso = new PhilippinePeso(msg.sender);
        EscrowFactory factory = new EscrowFactory(address(philippinePeso), inconvenienceThreshold);
        philippinePeso.transferOwnership(address(factory));
        vm.stopBroadcast();

        return factory;
    }
}
