// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AgentGate} from "../src/AgentGate.sol";
import {MockAgentIdRegistry} from "./mocks/MockAgentIdRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract AgentGateTest is Test {
    AgentGate public gate;
    MockAgentIdRegistry public registry;

    address public owner = address(this);
    address public alice = makeAddr("alice"); // Agent ID holder
    address public carol = makeAddr("carol"); // Agent ID holder
    address public bob = makeAddr("bob"); // NOT an Agent ID holder

    event Minted(address indexed minter, uint256 indexed tokenId);
    event BaseURISet(string baseURI);

    function setUp() public {
        registry = new MockAgentIdRegistry();
        registry.grant(alice);
        registry.grant(carol);
        gate = new AgentGate(address(registry), owner);
    }

    // --- happy path ---

    function test_HolderCanMint() public {
        vm.prank(alice);
        gate.mint();

        assertEq(gate.ownerOf(1), alice);
        assertEq(gate.balanceOf(alice), 1);
        assertTrue(gate.hasMinted(alice));
        assertEq(gate.nextTokenId(), 2);
    }

    function test_MultipleHoldersGetDistinctTokenIds() public {
        vm.prank(alice);
        gate.mint();
        vm.prank(carol);
        gate.mint();

        assertEq(gate.ownerOf(1), alice);
        assertEq(gate.ownerOf(2), carol);
        assertEq(gate.nextTokenId(), 3);
    }

    function test_MintEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(gate));
        emit Minted(alice, 1);
        vm.prank(alice);
        gate.mint();
    }

    // --- gate: Agent ID required ---

    function test_NonHolderReverts() public {
        vm.prank(bob);
        vm.expectRevert(AgentGate.NotAgentIdHolder.selector);
        gate.mint();
    }

    function test_RevokedAgentIdCannotMint() public {
        registry.revoke(alice);
        vm.prank(alice);
        vm.expectRevert(AgentGate.NotAgentIdHolder.selector);
        gate.mint();
    }

    // --- one mint per address ---

    function test_SecondMintReverts() public {
        vm.prank(alice);
        gate.mint();
        vm.prank(alice);
        vm.expectRevert(AgentGate.AlreadyMinted.selector);
        gate.mint();
    }

    // --- free: no BNB accepted ---

    function test_MintWithValueReverts() public {
        // mint() is non-payable, so a call carrying BNB must fail.
        // (Solidity forbids {value:} on a non-payable call at compile time,
        // so this is proven with a low-level call instead.)
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok,) = address(gate).call{value: 0.001 ether}(abi.encodeWithSignature("mint()"));
        assertFalse(ok);
        assertFalse(gate.hasMinted(alice));
    }

    // --- pause ---

    function test_PauseBlocksMintAndUnpauseResumes() public {
        gate.pause();
        assertTrue(gate.paused());
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        gate.mint();

        gate.unpause();
        assertFalse(gate.paused());
        vm.prank(alice);
        gate.mint();
        assertEq(gate.ownerOf(1), alice);
    }

    function test_NonOwnerCannotPauseOrUnpause() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        gate.pause();

        gate.pause();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        gate.unpause();
    }

    // --- metadata ---

    function test_TokenURIUsesBaseURI() public {
        gate.setBaseURI("https://example.com/meta/");
        vm.prank(alice);
        gate.mint();
        assertEq(gate.tokenURI(1), "https://example.com/meta/1");
    }

    function test_TokenURIEmptyWhenNoBaseURI() public {
        vm.prank(alice);
        gate.mint();
        assertEq(gate.tokenURI(1), "");
    }

    function test_TokenURINonexistentReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        gate.tokenURI(1);
    }

    function test_NonOwnerCannotSetBaseURI() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        gate.setBaseURI("https://evil.example/");
    }

    function test_SetBaseURIEmitsEvent() public {
        vm.expectEmit(false, false, false, true, address(gate));
        emit BaseURISet("https://example.com/meta/");
        gate.setBaseURI("https://example.com/meta/");
        assertEq(gate.baseTokenURI(), "https://example.com/meta/");
    }

    // --- constructor / ownership ---

    function test_OwnerIsDeployer() public view {
        assertEq(gate.owner(), owner);
    }

    function test_OwnerIsConstructorParam() public {
        // Production deploy goes through the CREATE2 proxy, so the owner must
        // come from the constructor argument, not msg.sender. Deploying with
        // the agent wallet as owner_ must make the agent wallet the owner.
        address agentWallet = 0x7b58AcABDA6C8ba6Ed814Bcb768D61bcC56fcD16;
        AgentGate gate2 = new AgentGate(address(registry), agentWallet);
        assertEq(gate2.owner(), agentWallet);
        // The proxy itself (msg.sender in the constructor) must NOT own it.
        assertTrue(gate2.owner() != address(this));
    }

    function test_ZeroOwnerReverts() public {
        // Ownable(owner_) reverts before the constructor body runs.
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new AgentGate(address(registry), address(0));
    }

    function test_ZeroRegistryReverts() public {
        vm.expectRevert("AgentGate: zero registry");
        new AgentGate(address(0), owner);
    }

    function test_RegistryAddressIsImmutable() public view {
        assertEq(address(gate.agentIdRegistry()), address(registry));
        // Mainnet Agent ID registry (SPACE ID Agent ID) for reference:
        // 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
    }
}
