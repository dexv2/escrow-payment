// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {EscrowFactory} from "../src/EscrowFactory.sol";
import {PhilippinePeso} from "../src/PhilippinePeso.sol";

contract DeployFactory is Script {
    function run() public returns (EscrowFactory, PhilippinePeso) {
        uint256 inconvenienceThreshold = 10;

        vm.startBroadcast(msg.sender);
        PhilippinePeso php = new PhilippinePeso(msg.sender);
        EscrowFactory factory = new EscrowFactory(address(php), inconvenienceThreshold);
        php.transferOwnership(address(factory));
        vm.stopBroadcast();

        return (factory, php);
    }
}
