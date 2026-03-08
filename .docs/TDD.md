# Technical Design Document (TDD): BanhMiCast Hybrid Integration
**Architecture:** Off-chain Encrypted Batching via Chainlink CRE + On-chain Verification via Sui Move.  
**Version:** 1.0 (Production Grade)  
**Security Level:** High (Threshold Decryption & DON-signed State Updates)

---

## 1. On-chain Module: `banhmicast::market`

### 1.1 Function: `commit_bet`
Users initiate their intent without revealing the direction of the bet.
*   **Params:**
    *   `market: &mut MarketObject`: The target prediction market.
    *   `payment: Coin<SUI>`: The investment amount.
    *   `blob_id: String`: The ID of the encrypted payload stored on Walrus.
    *   `commitment_hash: vector<u8>`: `sha3_256(plain_bet_details)`.
*   **Returns:** `BetCommitment` (Owned Object).
*   **Asserts/Requires:**
    *   `assert!(market.is_active, E_MARKET_CLOSED)`
    *   `assert!(coin::value(&payment) >= MIN_BET, E_INSUFFICIENT_FUNDS)`
    *   `assert!(vector::length(&commitment_hash) == 32, E_INVALID_HASH)`
*   **Gas Note:** This is a O(1) storage operation. Minimal gas usage.

### 1.2 Function: `resolve_batch_with_cre`
The primary entry point for the Chainlink DON to update the market state.
*   **Params:**
    *   `market: &mut MarketObject`: The shared market state.
    *   `batch_data: BatchUpdatePayload`: Contains `new_shares_supply`, `price_vec`, and `user_allocations`.
    *   `signature: vector<u8>`: The aggregated Threshold Signature from the DON.
    *   `bet_ids: vector<ID>`: List of `BetCommitment` objects being processed.
*   **Returns:** `void` (Emits `BatchResolvedEvent`).
*   **Logic:**
    1.  **Identity Verification:** Check if `signature` is valid against the stored `DON_PUBLIC_KEY`.
    2.  **Atomicity Check:** Verify that the number of `bet_ids` matches the `batch_data.allocation_count`.
    3.  **State Update:** Update `market.shares_supply` and `market.current_prices`.
    4.  **Distribution:** Convert `BetCommitment` objects into `UserPosition` (Shares) objects based on the computed LMSR price.
*   **Asserts:**
    *   `assert!(verify_don_signature(batch_data, signature), E_INVALID_PROOF)`
    *   `assert!(market.last_batch_id + 1 == batch_data.batch_id, E_OUT_OF_SEQUENCE)`

---

## 2. Off-chain Module: Chainlink CRE (JavaScript Execution)

### 2.1 Function: `calculateLMSRCost`
Implements the core Logarithmic Market Scoring Rule logic to determine price shifts.
*   **Logic:**
    *   $C(q) = b \cdot \ln(\sum_{j=1}^{N} e^{q_j/b})$
    *   `cost = calculateLMSRCost(new_q) - calculateLMSRCost(old_q)`
*   **Implementation:** Uses high-precision BigInt math to avoid floating point discrepancies between CRE nodes.

### 2.2 Function: `executeBatch`
*   **Input:** Array of `EncryptedOrders`, current `MarketState`.
*   **Process:**
    1.  **Threshold Decryption:** CRE nodes collaborate to decrypt the `blob_id` contents. No single node can see the data.
    2.  **Sequential Processing:** Sort orders by `CommitmentHash` (deterministic ordering) to prevent node-level bias.
    3.  **LMSR Calculation:** For each order, calculate how many shares are minted given the increasing price curve.
    4.  **Aggregated Proof:** Generate a Merkle Root of the state change.

---

## 3. Cryptographic & Security Architecture

### 3.1 Threshold Decryption Mechanism
To eliminate **Front-Running** and **Copy-Trading**:
1.  Users encrypt their `OutcomeIndex` using the **DON Public Key** ($PK_{don}$).
2.  The private key ($SK_{don}$) is split into $n$ shards using Shamir’s Secret Sharing.
3.  A threshold $k$ (e.g., $2/3$ of nodes) must provide a partial decryption share for the batch to be revealed inside the CRE.
4.  **Result:** The bet remains "Dark" (private) on Sui until the price is already locked in the batch.

### 3.2 Security Guardrails (The "Guru" Check)
*   **Slippage Guard:** The `resolve_batch_with_cre` function includes a `max_price_impact` parameter. If the off-chain calculation results in a price shift > X% for a single batch, the transaction reverts to protect users from thin liquidity manipulation.
*   **Linearizability:** By including `last_batch_id` in the on-chain state, we prevent "Replay Attacks" where a DON might try to submit the same profitable batch twice.

---

## 4. Error Handling & Edge Cases

| Edge Case | Impact | Resolution Mechanism |
| :--- | :--- | :--- |
| **CRE Liveness Failure** | Batch not processed | **Timeout Recovery:** If no batch is posted for 30 mins, users can call `emergency_refund()` to reclaim their `BetCommitment` collateral. |
| **Signature Mismatch** | Transaction Reverts | **Slashing/Reputation:** Chainlink Automation will retry with a different node subset. Consistent failure triggers a DON node audit. |
| **Insufficient Liquidity** | Price hits infinity | **LMSR Bound:** The `b` parameter (liquidity) is fixed at market creation. The contract prevents bets that exceed 90% of the mathematical limit. |
| **Gas Spike on Sui** | Delay in update | **Encrypted Queue:** Since bets are already committed and hashed, the delay doesn't allow front-running; it only delays the minting of share objects. |

---

## 5. Gas Optimization Strategy (Sui Micro-level)

1.  **Object Wrapping:** Instead of creating a new `Object` for every bet, the `resolve_batch_with_cre` function **destroys** the `BetCommitment` and returns the storage rebate to the user/caller, significantly lowering net transaction costs.
2.  **Vector Compression:** We pass `price_updates` as a `vector<u64>` (scaled integers) rather than decimals to minimize Move bytecode execution time.
3.  **PTB Atomicity:** We utilize Sui **Programmable Transaction Blocks** to allow the DON to:
    *   Fetch all `BetCommitment` objects.
    *   Call `resolve_batch_with_cre`.
    *   Emit events.
    *   All in one single Gas-efficient execution.