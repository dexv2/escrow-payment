// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address[] public supportedStablecoins;
    uint256 deployerKey;

    constructor() {
        if (block.chainid == 11155111) {
            getSepoliaConfig();
        }
        else {
            getOrCreateAnvilNetworkConfig();
        }
    }

    function getSepoliaConfig() public {
        /** 
         * ADD SEPOLIA STABLECOINS 
         */
        // supportedStablecoins = [address, address, address];
        deployerKey = vm.envUint("PRIVATE_KEY");
    }

    function getOrCreateAnvilNetworkConfig() public {
        if (supportedStablecoins.length > 0) {
            return;
        }

        vm.startBroadcast();
        ERC20Mock usd1 = new ERC20Mock("USD1", "USD1", msg.sender, 1000e18);
        ERC20Mock usd2 = new ERC20Mock("USD2", "USD2", msg.sender, 1000e18);
        ERC20Mock usd3 = new ERC20Mock("USD3", "USD3", msg.sender, 1000e18);
        vm.stopBroadcast();

        supportedStablecoins = [
            address(usd1),
            address(usd2),
            address(usd3)
        ];
        deployerKey = DEFAULT_ANVIL_KEY;
    }

    function getSupportedStablecoins() public view returns (address[] memory) {
        return supportedStablecoins;
    }
}
