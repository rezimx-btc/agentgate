// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AgentGate} from "../src/AgentGate.sol";
import {MockAgentIdRegistry} from "../test/mocks/MockAgentIdRegistry.sol";

/// @notice LOCAL-ONLY demo: deploy MockAgentIdRegistry + AgentGate to a local
///         anvil chain and grant an Agent ID to anvil account #1, so the
///         mint() gas cost can be measured end-to-end. NEVER run on mainnet:
///         the mock registry is not the real SPACE ID Agent ID registry.
contract LocalDemo is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address holder = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // anvil account #1

        vm.startBroadcast(deployerKey);
        MockAgentIdRegistry registry = new MockAgentIdRegistry();
        AgentGate gate = new AgentGate(address(registry), vm.addr(deployerKey));
        registry.grant(holder);
        vm.stopBroadcast();

        console.log("Mock registry:", address(registry));
        console.log("AgentGate (local):", address(gate));
        console.log("Holder granted:", holder);
    }
}
