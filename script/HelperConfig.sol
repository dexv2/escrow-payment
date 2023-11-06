// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";
import {STCFaucet} from "../test/mocks/FaucetMock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address[] supportedStablecoins;
        uint256 deployerKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        }
        else {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        }
    }

    function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        if (activeNetworkConfig.supportedStablecoins.length > 0) {
            return activeNetworkConfig;
        }
    }
}
