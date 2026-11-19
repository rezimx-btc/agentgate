// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title AgentGate
/// @notice Free-mint ERC-721 that can ONLY be claimed by holders of an Agent ID
///         (SPACE ID Agent ID registry on BNB Chain). One free mint per address.
/// @dev Gate: registry.balanceOf(msg.sender) > 0. The Agent ID registry is
///      ERC-721, non-transferable, one Agent ID per user, so a per-address
///      mint cap is equivalent to a per-Agent-ID cap.
/// @dev The contract holds NO user funds: mint() is non-payable, there is no
///      payable function and no withdraw function. The only thing a minter
///      pays is the BSC network gas for their own mint transaction.
/// @dev Owner permissions (fully documented, see README.md):
///      - setBaseURI(string): change the metadata base URI.
///      - pause() / unpause(): emergency stop / resume of minting.
///      The owner CANNOT mint for others, CANNOT change the Agent ID registry,
///      CANNOT raise the per-address cap, CANNOT take or move any token,
///      and CANNOT withdraw funds (there are none to withdraw).
interface IAgentIdRegistry {
    function balanceOf(address account) external view returns (uint256);
}

contract AgentGate is ERC721, Ownable, Pausable {
    using Strings for uint256;

    /// @notice SPACE ID Agent ID registry (BNB Chain, ERC-721, non-transferable).
    IAgentIdRegistry public immutable agentIdRegistry;

    /// @notice Next token ID to mint (starts at 1).
    uint256 public nextTokenId = 1;

    /// @notice True once an address has claimed its one free mint.
    mapping(address => bool) public hasMinted;

    /// @notice Base URI for token metadata (empty until set by owner).
    string private _baseTokenURI;

    /// @notice Emitted when an Agent ID holder claims a free mint.
    event Minted(address indexed minter, uint256 indexed tokenId);

    /// @notice Emitted when the owner changes the metadata base URI.
    event BaseURISet(string baseURI);

    error NotAgentIdHolder();
    error AlreadyMinted();

    /// @notice Deploys with an explicit owner because production deployment goes
    ///      through the deterministic deployment proxy (CREATE2): in that flow
    ///      msg.sender inside the constructor is the proxy, NOT the deployer,
    ///      so Ownable(msg.sender) would strand ownership on the proxy.
    /// @param agentIdRegistry_ SPACE ID Agent ID registry (must be non-zero).
    /// @param owner_ Owner of the contract (must be non-zero).
    constructor(address agentIdRegistry_, address owner_) ERC721("AgentGate", "AGATE") Ownable(owner_) {
        // Note: Ownable(owner_) itself reverts OwnableInvalidOwner(0) on a
        // zero owner before this body runs, so no separate check is needed.
        require(agentIdRegistry_ != address(0), "AgentGate: zero registry");
        agentIdRegistry = IAgentIdRegistry(agentIdRegistry_);
    }

    /// @notice Claim the one free AgentGate NFT for this address.
    /// @dev Requirements:
    ///      - minting is not paused,
    ///      - caller holds at least one Agent ID in the registry,
    ///      - caller has not minted before.
    ///      Non-payable: no BNB is accepted, minter pays only network gas.
    function mint() external whenNotPaused {
        if (agentIdRegistry.balanceOf(msg.sender) < 1) revert NotAgentIdHolder();
        if (hasMinted[msg.sender]) revert AlreadyMinted();

        hasMinted[msg.sender] = true;
        uint256 tokenId = nextTokenId;
        nextTokenId += 1;

        // Event emitted before the external _safeMint call (lint: reentrancy-events).
        // Safe: a revert in _safeMint rolls the whole transaction back, log included.
        emit Minted(msg.sender, tokenId);
        _safeMint(msg.sender, tokenId);
    }

    /// @notice Set the metadata base URI. Only the owner.
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
        emit BaseURISet(baseURI_);
    }

    /// @notice Emergency pause of minting. Only the owner.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resume minting after a pause. Only the owner.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Token metadata URI: baseURI + tokenId, or "" if no base URI set.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        string memory base = _baseTokenURI;
        if (bytes(base).length == 0) return "";
        return string.concat(base, tokenId.toString());
    }

    /// @dev Expose the base URI for frontends / indexers.
    function baseTokenURI() external view returns (string memory) {
        return _baseTokenURI;
    }
}
