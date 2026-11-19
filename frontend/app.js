// AgentGate frontend — static, no backend, no build step.
// Reads via eth_call (window.ethereum, fallback: public BSC RPC) and sends
// exactly one transaction: mint() on the AgentGate contract.
// All function selectors below were verified with `cast sig` (keccak_256):
//   balanceOf(address) = 0x70a08231   mint() = 0x1249c58b
//   hasMinted(address) = 0x38e21cce   nextTokenId() = 0x75794a3c
"use strict";

const AGENT_ID_REGISTRY = "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F";
// TODO after deploy: replace with the real AgentGate contract address on BSC (chain 56).
const CONTRACT_ADDRESS = "0x8A1DC3632fbf543b99092ba0420d128eFa7cAa39";
const BSC_CHAIN_ID_HEX = "0x38"; // 56
const BSC_RPC_FALLBACK = "https://bsc-dataseed.binance.org";
const BSCSCAN = "https://bscscan.com";

const SEL = {
  balanceOf: "0x70a08231",
  mint: "0x1249c58b",
  hasMinted: "0x38e21cce",
  nextTokenId: "0x75794a3c",
};

const $ = (id) => document.getElementById(id);
let account = null;

function log(msg) {
  $("log").textContent += msg + "\n";
}

function setStatus(msg, cls) {
  const el = $("status");
  el.textContent = msg;
  el.className = cls || "muted";
}

function padAddress(addr) {
  return "0x" + "000000000000000000000000" + addr.slice(2).toLowerCase();
}

// Generic eth_call: prefer the injected provider, fall back to public RPC.
async function ethCall(to, data) {
  const params = [{ to, data }, "latest"];
  if (window.ethereum) {
    try {
      return await window.ethereum.request({ method: "eth_call", params });
    } catch (e) {
      log("injected eth_call failed, trying public RPC: " + (e && e.message));
    }
  }
  const res = await fetch(BSC_RPC_FALLBACK, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_call", params }),
  });
  const json = await res.json();
  if (json.error) throw new Error(json.error.message || "RPC error");
  return json.result;
}

async function refreshMintedCount() {
  if (CONTRACT_ADDRESS === "0x0000000000000000000000000000000000000000") {
    $("mintedCount").textContent = "contract not deployed yet";
    return;
  }
  try {
    const raw = await ethCall(CONTRACT_ADDRESS, SEL.nextTokenId);
    const next = parseInt(raw, 16);
    $("mintedCount").textContent = String(next - 1);
  } catch (e) {
    $("mintedCount").textContent = "unavailable";
    log("nextTokenId read failed: " + (e && e.message));
  }
}

async function refreshEligibility() {
  const mintBtn = $("mintBtn");
  mintBtn.disabled = true;
  if (!account) return;
  if (CONTRACT_ADDRESS === "0x0000000000000000000000000000000000000000") {
    setStatus("Contract not deployed yet — minting opens after deployment.", "bad");
    return;
  }
  try {
    const balRaw = await ethCall(AGENT_ID_REGISTRY, SEL.balanceOf + padAddress(account).slice(2));
    const agentBal = parseInt(balRaw, 16);
    if (agentBal < 1) {
      setStatus("This address holds no Agent ID, so it cannot mint. Agent ID can only be claimed inside the Binance App (Wallet > Agent ID).", "bad");
      return;
    }
    const mintedRaw = await ethCall(CONTRACT_ADDRESS, SEL.hasMinted + padAddress(account).slice(2));
    const already = parseInt(mintedRaw, 16) !== 0;
    if (already) {
      setStatus("You already claimed your one free AgentGate. Thank you!", "ok");
      return;
    }
    setStatus("Agent ID confirmed (" + agentBal + "). You can mint your one free AgentGate.", "ok");
    mintBtn.disabled = false;
  } catch (e) {
    setStatus("Could not check eligibility: " + (e && e.message), "bad");
    log("eligibility check failed: " + (e && e.message));
  }
}

async function connect() {
  if (!window.ethereum) {
    setStatus("No EIP-1193 wallet found. Install MetaMask or Binance Wallet and reload.", "bad");
    return;
  }
  try {
    const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
    account = accounts[0];
    const chainId = await window.ethereum.request({ method: "eth_chainId" });
    if (chainId !== BSC_CHAIN_ID_HEX) {
      setStatus("Please switch your wallet to BNB Chain (chain id 56).", "bad");
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: BSC_CHAIN_ID_HEX }],
        });
      } catch (e) {
        log("chain switch failed: " + (e && e.message));
        return;
      }
    }
    $("connectBtn").textContent = "Connected: " + account.slice(0, 6) + "…" + account.slice(-4);
    log("connected " + account);
    await refreshEligibility();
  } catch (e) {
    setStatus("Connection failed: " + (e && e.message), "bad");
  }
}

async function mint() {
  if (!account) return;
  const mintBtn = $("mintBtn");
  mintBtn.disabled = true;
  setStatus("Waiting for your confirmation in the wallet — this sends ONLY mint() to the AgentGate contract (no BNB value).");
  try {
    const txHash = await window.ethereum.request({
      method: "eth_sendTransaction",
      params: [{ from: account, to: CONTRACT_ADDRESS, data: SEL.mint, value: "0x0" }],
    });
    $("txLine").innerHTML =
      'Transaction sent: <a href="' + BSCSCAN + "/tx/" + txHash + '" target="_blank" rel="noopener">' + txHash + "</a>";
    setStatus("Mint transaction sent. Waiting for confirmation…");
    log("mint tx " + txHash);
    await refreshEligibility();
    await refreshMintedCount();
  } catch (e) {
    setStatus("Mint cancelled or failed: " + (e && e.message), "bad");
    log("mint failed: " + (e && e.message));
    await refreshEligibility();
  }
}

$("connectBtn").addEventListener("click", connect);
$("mintBtn").addEventListener("click", mint);
if (window.ethereum) {
  window.ethereum.on("accountsChanged", (accs) => {
    account = accs[0] || null;
    $("connectBtn").textContent = account ? "Connected: " + account.slice(0, 6) + "…" + account.slice(-4) : "Connect wallet";
    refreshEligibility();
  });
  window.ethereum.on("chainChanged", () => window.location.reload());
}
refreshMintedCount();
