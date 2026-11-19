// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal stand-in for the SPACE ID Agent ID registry.
/// @dev AgentGate only calls balanceOf(address), so this mock exposes exactly
///      that plus grant()/revoke() helpers for tests. It is NOT a real ERC-721.
contract MockAgentIdRegistry {
    mapping(address => uint256) private _balances;

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function grant(address account) external {
        _balances[account] = 1;
    }

    function revoke(address account) external {
        _balances[account] = 0;
    }
}
