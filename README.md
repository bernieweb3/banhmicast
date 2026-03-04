<div align="center">

# 🥖 BanhMiCast

**Privacy-Preserving Prediction Market on Sui**  
*Joint-Outcome AMM · Chainlink CRE · Walrus Storage*

[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](./LICENSE)
[![Sui Testnet](https://img.shields.io/badge/Sui-Testnet-4CA2FF?logo=sui)](https://suiscan.xyz/testnet/object/0x352a63e9364222707eeeaae0d49bac9bce2b089a2ceeeebf0716f7701932c32f)
[![Chainlink CRE](https://img.shields.io/badge/Chainlink-CRE%20Workflow-375BD2?logo=chainlink)](./packages/cre-workflow)
[![Walrus](https://img.shields.io/badge/Storage-Walrus%20Testnet-F2A65A)](https://walrus.space)

</div>

---

## Overview

BanhMiCast is a decentralised prediction market built natively on the **Sui blockchain**. It solves the two biggest problem in prediction markets today:

| Problem | BanhMiCast Solution |
|:---|:---|
| **Liquidity fragmentation** across many outcomes | **Joint-Outcome AMM (World Table)** — all outcomes share a unified pool |
| **Front-running & copy-trading bots** | **Encrypted Batching** — user intent stays hidden until the CRE batch is sealed |

The system uses **Chainlink Runtime Environment (CRE)** as a privacy-preserving off-chain compute layer, **Walrus** as decentralised encrypted payload storage, and **Sui Move** for high-concurrency on-chain settlement.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User (Browser)                              │
│  Client-side encrypt bet payload → submit commitment hash to Sui    │
└───────────────┬────────────────────────────────────┬────────────────┘
                │                                    │
                ▼                                    ▼
   ┌────────────────────┐               ┌────────────────────────┐
   │  Walrus (Storage)  │               │   Sui Blockchain (L1)  │
   │  Encrypted Blob    │               │   BetCommitment object │
   │  ← Blob ID →       │               │   MarketObject (shared)│
   └────────────────────┘               └────────────┬───────────┘
                                                     │
                              ┌──────────────────────┘
                              ▼
                 ┌────────────────────────┐
                 │  Chainlink CRE (WASM)  │
                 │  1. Fetch blobs        │
                 │  2. Decrypt batch      │
                 │  3. LMSR compute       │
                 │  4. ExecutionResult    │
                 └────────────┬───────────┘
                              │
                              ▼
                 ┌────────────────────────┐
                 │  Sui Blockchain (L1)   │
                 │  Verify DON signature  │
                 │  Update WorldTable     │
                 │  Mint share objects    │
                 └────────────────────────┘
```

### Key Components

| Package | Language | Purpose |
|:---|:---|:---|
| `packages/move` | Sui Move | On-chain: market state, escrow, DON verifier |
| `packages/cre-workflow` | Go + WASM | Chainlink CRE: LMSR compute + Walrus HTTP |
| `packages/cre` | JavaScript | Off-chain helpers: LMSR engine, batch processor, Walrus client |
| `packages/shared` | JavaScript | Shared constants, types |
| `packages/frontend` | React + Vite | Web UI: Explore, War Room (WorldTable + BettingPanel), Portfolio |

---

## Chainlink CRE Integration

> 📋 **Hackathon requirement:** All Chainlink-related files are listed here.

| File | Role |
|:---|:---|
| [`packages/cre-workflow/banhmicast-batch/main.go`](./packages/cre-workflow/banhmicast-batch/main.go) | CRE Workflow entry point — `wasm.NewRunner` + `cron.Trigger` |
| [`packages/cre-workflow/banhmicast-batch/lmsr.go`](./packages/cre-workflow/banhmicast-batch/lmsr.go) | LMSR pricing engine in Go (pure BigInt) |
| [`packages/cre-workflow/project.yaml`](./packages/cre-workflow/project.yaml) | CRE project config (RPC targets) |
| [`packages/cre-workflow/banhmicast-batch/workflow.yaml`](./packages/cre-workflow/banhmicast-batch/workflow.yaml) | CRE workflow config (cron trigger + config path) |
| [`packages/cre-workflow/banhmicast-batch/config.testnet.json`](./packages/cre-workflow/banhmicast-batch/config.testnet.json) | Testnet simulation config (Walrus URL, market ID, sample commitments) |

### Simulating the CRE Workflow

```bash
# 1. Install CRE CLI (see Prerequisites below)

# 2. Login
cre login

# 3. Run simulation (from project root)
cd packages/cre-workflow
cre workflow simulate banhmicast-batch --target testnet-settings

# With verbose output (recommended for demo)
cre workflow simulate banhmicast-batch --target testnet-settings --verbose
```

**Expected output:**

```
✓ Workflow compiled
[USER LOG] 🥖 BanhMiCast batch epoch started
[USER LOG] 📦 Fetching blobs from Walrus  count=2
[USER LOG] ✅ Walrus blobs fetched
[USER LOG] 🔓 Decryption complete  valid=2 rejected=0
[USER LOG] 🎯 ExecutionResult computed  allocations=2
[USER LOG] ✅ Batch complete — ready for Sui submission
✓ Simulation complete!
```

---

## Deployed Contracts (Sui Testnet)

| Object | ID |
|:---|:---|
| **Package** | [`0x352a...c32f`](https://suiscan.xyz/testnet/object/0x352a63e9364222707eeeaae0d49bac9bce2b089a2ceeeebf0716f7701932c32f) |
| **AdminCap** | `0xad72...2437` |
| **VerifierConfig** (shared) | `0x1ff1...4f5b` |

Modules: `errors` · `escrow` · `market` · `verifier`

---

## Prerequisites

| Tool | Version | Install |
|:---|:---|:---|
| Go | ≥ 1.22 | `brew install go` |
| Sui CLI | latest | [docs.sui.io](https://docs.sui.io/guides/developer/getting-started/sui-install) |
| CRE CLI | v1.2.0 | [Download binary](https://github.com/smartcontractkit/cre-cli/releases) |
| Node.js | ≥ 18 | [nodejs.org](https://nodejs.org) |

### Installing CRE CLI (macOS ARM)

```bash
# Download
curl -L https://github.com/smartcontractkit/cre-cli/releases/download/v1.2.0/cre_darwin_arm64.zip -o /tmp/cre.zip
unzip /tmp/cre.zip -d /tmp/cre-bin

# Install
sudo cp /tmp/cre-bin/cre_v1.2.0_darwin_arm64 /opt/homebrew/bin/cre
chmod +x /opt/homebrew/bin/cre

# Verify
cre version   # → CRE CLI version v1.2.0
```

---

## Installation

```bash
# Clone
git clone https://github.com/<your-org>/banhmicast.git
cd banhmicast

# Install JavaScript dependencies (CRE helpers + tests)
cd packages/cre && npm install
cd ../shared && npm install

# Install and run frontend
cd ../frontend && npm install
npm run dev   # → http://localhost:5173
```

### Build Move Contracts

```bash
cd packages/move
sui move build
```

### Run All Tests

```bash
# Move unit tests
cd packages/move
sui move test

# CRE JavaScript tests (Jest)
cd packages/cre
npm test

# Or run both with the convenience script:
bash scripts/test-all.sh
```

---

## Running the CRE Workflow Simulation

```bash
# From project root
cd packages/cre-workflow

# Create .env (optional — only needed for --broadcast)
cp .env.example .env

# Simulate (dry-run, no wallet needed)
cre workflow simulate banhmicast-batch --target testnet-settings

# Non-interactive mode (for CI/demo)
cre workflow simulate banhmicast-batch --target testnet-settings \
    --non-interactive --trigger-index 0
```

### How It Works

1. **Cron trigger** fires — CRE CLI compiles `main.go` to WASM and starts the workflow.
2. **Walrus HTTP fetch** — the workflow fetches each encrypted bet blob from `aggregator.walrus-testnet.walrus.space`.
3. **Decrypt & verify** — inside the WASM sandbox; plaintext never leaves.
4. **LMSR batch compute** — deterministic BigInt pricing, sorted by commitment hash.
5. **ExecutionResult** — JSON output contains new share supplies, price updates (`5×10¹⁷ = 50%`), and per-user allocations.

---

## How the LMSR Pricing Works

BanhMiCast uses the **Logarithmic Market Scoring Rule**:

```
C(q) = b × ln( Σ exp(qᵢ / b) )
P(i) = exp(qᵢ / b) / Σ exp(qⱼ / b)
```

- `b` — liquidity parameter (controls price sensitivity); set at market creation.
- `qᵢ` — outstanding shares for outcome `i`.
- Prices always sum to 1 (probability-preserving).

All arithmetic uses `BigInt` with 18-decimal fixed-point precision to avoid floating-point drift across DON nodes.

---

## Deploying to Sui Testnet

```bash
cd packages/move

# Make sure your wallet has testnet SUI
sui client faucet

# Deploy
sui client publish --gas-budget 200000000

# After deploy, initialise VerifierConfig
sui client ptb \
  --move-call <PACKAGE_ID>::verifier::initialize \
  --args <ADMIN_CAP_ID> <DON_PUBLIC_KEY_HEX>
```

> See [`DEPLOYMENT.md`](./DEPLOYMENT.md) for the current testnet contract addresses.

---

## Project Structure

```
banhmicast/
├── packages/
│   ├── move/                  # Sui Move smart contracts
│   │   └── sources/
│   │       ├── market.move    # WorldTable (shared object)
│   │       ├── escrow.move    # Collateral locking & payout
│   │       ├── verifier.move  # DON signature verification
│   │       └── errors.move    # Error constants
│   ├── cre-workflow/          # Chainlink CRE Workflow (Go → WASM)
│   │   ├── project.yaml
│   │   └── banhmicast-batch/
│   │       ├── main.go        # Workflow entry point
│   │       ├── lmsr.go        # LMSR pricing engine
│   │       ├── workflow.yaml
│   │       └── config.testnet.json
│   ├── cre/                   # JS off-chain helpers
│   │   └── src/
│   │       ├── cre-handler.js
│   │       ├── lmsr-engine.js
│   │       ├── batch-processor.js
│   │       ├── walrus-client.js
│   │       └── decryptor.js
│   ├── frontend/              # React web UI (Vite)
│   │   └── src/
│   │       ├── components/    # MarketCard, WorldTable, BettingPanel, etc.
│   │       ├── pages/         # ExplorePage, MarketPage, PortfolioPage
│   │       ├── styles/        # Obsidian Crust design system CSS
│   │       └── lib/           # sui-config.js (contract addresses)
│   └── shared/                # Shared constants & types
├── scripts/
│   └── test-all.sh
├── DEPLOYMENT.md
├── LICENSE
└── README.md
```

---

## Security

- **Anti-Front-Running** — bets are encrypted client-side before submission; validators only see commitment hashes.
- **Threshold Decryption** — no single CRE node can decrypt a batch alone; requires a 2/3 quorum of DON nodes.
- **Replay Protection** — `last_batch_id` in `MarketObject` prevents batch replay attacks.
- **Emergency Refund** — if no CRE update occurs within the grace period, users can call `emergency_refund()` to reclaim collateral.

---

## License

This project is licensed under a **Custom Proprietary License**. In summary:

- **Research / Educational use** requires prior written permission from the author.
- **Commercial use** is strictly prohibited.
- **Modification** requires prior written permission from the author.
- **Hackathon submissions** are permitted only with written permission **and** ≥ 70% original code.
- **Startup competition use** is unconditionally prohibited.

See [`LICENSE`](./LICENSE) for the full, legally binding terms.

📧 Permission requests: **bernie.web3@gmail.com**

---

## Author

**Bernie Nguyen**  
Email: [bernie.web3@gmail.com](mailto:bernie.web3@gmail.com)

---

<div align="center">

Built with ❤️ on Sui · Powered by Chainlink CRE · Stored on Walrus

</div>
