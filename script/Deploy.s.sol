// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AgentGate} from "../src/AgentGate.sol";

/// @notice Deploy AgentGate to BNB Chain (chain id 56).
/// @dev Usage (DO NOT run without funding + explicit approval):
///      export PRIVATE_KEY=<deployer key>   # never commit this
///      forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.binance.org \
///          --broadcast --verify --etherscan-api-key <BscScan key> -vvvv
///      The deployer needs enough BNB for the deployment gas (see
///      COORDINATOR-SUMMARY.md for the measured estimate). The agent wallet
///      currently holds ~0.00016552 BNB, which is NOT enough — deploy is
///      blocked until Uzan funds the deployer and approves in the Binance App.
contract Deploy is Script {
    /// @notice SPACE ID Agent ID registry on BNB Chain (mainnet).
    address public constant AGENT_ID_REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external returns (AgentGate gate) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        console.log("Deployer:", deployer);
        console.log("Agent ID registry:", AGENT_ID_REGISTRY);

        vm.startBroadcast(deployerKey);
        gate = new AgentGate(AGENT_ID_REGISTRY, deployer);
        vm.stopBroadcast();

        console.log("AgentGate deployed at:", address(gate));
        console.log("Owner:", gate.owner());
        console.log("Registry:", address(gate.agentIdRegistry()));
    }
}
