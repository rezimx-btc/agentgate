# AgentGate — Free mint for Agent ID holders

**One free NFT, claimable only by holders of an Agent ID.**
Built for the Agent ID Hackathon (Binance Wallet + BNB Chain, 60,000 USDC,
submission period 2026-11-18 → 2026-12-09 08:00 UTC).

No price. No presale. No promises of returns. The contract accepts no BNB —
a minter pays only the BSC network gas for their own mint transaction.

## How it works

1. A user connects their wallet on BNB Chain (MetaMask / Binance Wallet).
2. `AgentGate.mint()` checks the SPACE ID Agent ID registry
   (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, ERC-721, non-transferable):
   `balanceOf(caller) > 0` means the caller holds an Agent ID.
3. If the caller holds an Agent ID and has not minted before, one `AgentGate`
   NFT (ERC-721, token IDs from 1) is minted to them. One mint per address.
   (Each user can hold only one Agent ID, so a per-address cap is equivalent
   to a per-Agent-ID cap.)
4. Metadata: `tokenURI(tokenId)` returns `baseURI + tokenId` once the owner
   sets a base URI; empty string until then.

Why this concept: the hackathon's Project Awards rank by the number of
interacting Agent ID addresses, transaction volume, and transaction count.
A genuinely free mint is the most honest way to attract real Agent ID
interaction — no paywall, no speculation hook.

## Contract

- `src/AgentGate.sol` — ERC-721 (`AgentGate` / `AGATE`), OpenZeppelin v5.4.0
  (`ERC721`, `Ownable`, `Pausable`), Solidity 0.8.38, optimizer on (200 runs).
- Registry is `immutable`, set once in the constructor.
- `mint()` is **non-payable**. There is **no payable function and no
  withdraw function** — the contract can never hold user funds.

### Owner permissions (complete — nothing hidden)

| Function | Who | What it does | What it CANNOT do |
|---|---|---|---|
| `setBaseURI(string)` | owner | Change the metadata base URI | — |
| `pause()` / `unpause()` | owner | Emergency stop / resume minting | — |
| (constructor) | deployer | Sets registry + becomes owner | — |

The owner **cannot**: mint for anyone else, change the Agent ID registry,
raise the one-mint-per-address cap, take or move any token, change the mint
price (there is none), or withdraw funds (there are none to withdraw).
There is no upgrade proxy and no hidden admin.

## Tests

```bash
forge test
```

17 tests, all passing, zero compiler warnings:

- Holder can mint; non-holder reverts (`NotAgentIdHolder`); revoked Agent ID
  cannot mint; second mint reverts (`AlreadyMinted`).
- Mint with BNB attached reverts (non-payable, proven by low-level call).
- Pause blocks minting, unpause resumes; non-owner cannot pause/unpause or
  set the base URI.
- `tokenURI` = base URI + token ID; empty when no base URI; nonexistent
  token reverts; constructor rejects the zero registry.
- A mock registry (`test/mocks/MockAgentIdRegistry.sol`) stands in for the
  real Agent ID registry in tests — the contract only calls `balanceOf`.

## Deploy (DONE — live on BNB Chain)

Deployed 2026-11-19 14:55 WIB via the Arachnid deterministic-deployment-proxy
(CREATE2, salt 0):

- Contract: `0x8A1DC3632fbf543b99092ba0420d128eFa7cAa39`
- Deploy tx: `0x0d3f6d4fdf48f3aa6ca4c0589650962ea787ea4e5b31fd3bc8bf9003b3f7bb5e`
  (block 134,466,919; 1,392,994 gas @ 0.06397 gwei = 0.0000891 BNB fee)
- Owner: agent wallet `0x7b58acabda6c8ba6ed814bcb768d61bcc56fcd16`
- Source verified: Sourcify EXACT MATCH (creation + runtime),
  verified 2026-11-19 07:57:57 UTC
- Test mint: token #1 minted to the agent wallet 2026-11-19 14:59 WIB,
  tx `0xc3264657af6f24ea0f3c19c90c52d180cc5a5c0cb5e8489600117bb19665ea12`
  (105,136 gas @ 0.105955123 gwei = 0.0000111 BNB fee)

Measured deployment gas (local anvil, real broadcast): **2,525,042 gas**.
Mint gas (local anvil, real broadcast): **105,193 gas**.

| Gas price | Deploy cost | Mint cost |
|---|---|---|
| 0.05 gwei | 0.00012625 BNB | 0.00000526 BNB |
| 0.1 gwei | 0.00025250 BNB | 0.00001052 BNB |
| 0.5 gwei | 0.00126252 BNB | 0.00005260 BNB |
| 1 gwei | 0.00252504 BNB | 0.00010519 BNB |
| 3 gwei | 0.00757513 BNB | 0.00031558 BNB |

Live mint page: https://muse.ai/s/agentgate-xcj6xa6xpojxzxm4/CrE1XrKUVo_xsXnvdM7xfQJyEI0dK1UYVBalItg0QbM

To redeploy from source (needs a funded deployer key):

```bash
export PRIVATE_KEY=<deployer key>   # never commit this
forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.binance.org \
    --broadcast --verify --etherscan-api-key <BscScan key> -vvvv
```

Note: the deploy script deploys directly; the live deployment above went
through the deterministic proxy instead, because the deployer wallet is a
Binance Agentic Wallet with no direct deploy command. The proxy route needs
the `owner_` constructor parameter (see `src/AgentGate.sol`) so ownership
lands on the deployer, not on the proxy.

## Frontend

`frontend/` is a static site — no backend, no server, no build step. Open
`index.html` (or host the folder anywhere static).

- Connects via EIP-1193 (`window.ethereum`), switches to BNB Chain (56).
- Reads `balanceOf(address)` on the Agent ID registry and
  `hasMinted(address)` / `nextTokenId()` on AgentGate via `eth_call`.
- The Mint button sends exactly one transaction: `mint()` with `value: 0x0`.
  The wallet shows the call before the user confirms it.
- It never asks for a seed phrase, private key, API secret, or pairing code.
  There is no web QR login and no session is stored anywhere.

## Hackathon submission

There is **no separate hackathon portal**. Projects are submitted ONLY through
the Binance survey (verified 2026-11-19 14:31 WIB):

- Project submission survey: https://app.binance.com/uni-qr/user-survey/fb26d2bd25e04329b1ba77c7b3811d23
  (title in Chinese: "Agent ID 黑客松参赛项目提交表")
- Community Promotion survey (X post): https://app.binance.com/uni-qr/user-survey/ff6832f8d2984af289068c9450a3c98c

Both surveys are **locked behind a Binance account login** — the exact fields
inside the forms cannot be verified without logging in. The announcement
names these fields: project name, website, contract address(es), Agent ID
usage description, plus "other required information". **Final submission must
be done by the project owner from their own Binance account; login cannot be
delegated.**

Deadline: **2026-12-09 08:00 UTC (= 15:00 WIB)**.

### Eligibility checklist (honest status, 2026-11-19)

- [x] Deployed on BNB Chain — YES (0x8A1DC3632fbf543b99092ba0420d128eFa7cAa39,
      2026-11-19 14:55 WIB)
- [x] Source verified + open-source — YES (Sourcify EXACT MATCH;
      this repo is public)
- [x] Actively uses Agent ID — YES (access control via registry `balanceOf`)
- [ ] Innovation Award eligibility (≥ 30 Agent ID addresses interacting
      during the Submission Period) — IN PROGRESS (3/30 as of 2026-11-19)
- [x] Safety red lines — PASS: no web QR login, no session storage, no
      bypass of user transaction confirmation, no unauthorized transfers,
      no unlimited approvals, no credential collection, no promised returns,
      Agent ID is not used as a "lookup other people's wallets" tool, and
      the name "AgentGate" does not impersonate Binance/BNB.

## Community Promotion (separate, 20 winners × 100 USDC)

Post original content on X about a participating project with the hashtags
`#BinanceWalletHackathon` and `#AgenticWallet`, then submit the X link via
the community survey above. (Posting itself must be done from the owner's
own X account.)

## Repo layout

```
src/AgentGate.sol            contract
test/AgentGate.t.sol         17 Foundry tests
test/mocks/MockAgentIdRegistry.sol   test-only registry stand-in
script/Deploy.s.sol          BSC mainnet deploy script
script/LocalDemo.s.sol       LOCAL-ONLY anvil demo (mock registry)
frontend/index.html + app.js static mint page
SUBMISSION-DRAFT.md          draft submission text
COORDINATOR-SUMMARY.md       build log + what is still needed
```

## License

MIT — see `LICENSE`.
