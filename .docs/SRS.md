# Software Requirements Specification (SRS) for BanhMiCast

**Project:** BanhMiCast – Next-Gen Prediction Market  
**Version:** 1.0-DRAFT  
**Status:** High-Level Architecture & Requirements  
**Framework:** Sui Blockchain (Move) + Chainlink Runtime Environment (CRE)

---

## 1. Introduction

### 1.1 Purpose
This document specifies the functional and non-functional requirements for **BanhMiCast**, a decentralized prediction market. BanhMiCast utilizes a **Joint-Outcome AMM (World Table)** model to solve liquidity fragmentation and leverages **Chainlink Runtime Environment (CRE)** for encrypted batching and $0-cost off-chain computation.

### 1.2 Scope
BanhMiCast provides a platform for users to trade on the outcome of future events. Unlike traditional prediction markets, BanhMiCast uses the "World Table" approach to unify liquidity across different event outcomes and utilizes Sui’s object-centric model for high-concurrency settlement.

### 1.3 Definitions, Acronyms, and Abbreviations
*   **AMM:** Automated Market Maker.
*   **CRE:** Chainlink Runtime Environment.
*   **DON:** Decentralized Oracle Network.
*   **Joint-Outcome AMM (World Table):** A liquidity model where multiple markets share a unified liquidity pool.
*   **Encrypted Batching:** A process where user bets are encrypted and batched off-chain to prevent MEV and front-running.
*   **Move:** The programming language used by the Sui blockchain.

---

## 2. Overall Description

### 2.1 Product Perspective
BanhMiCast is a decentralized application (dApp) consisting of:
1.  **On-chain Logic (Sui/Move):** Handles asset custody, market state, and final settlement.
2.  **Off-chain Compute (Chainlink CRE):** Handles the "World Table" AMM math (LMSR/CPMM variations), batching of orders, and outcome verification.
3.  **Frontend:** A React/Sui-wallet integrated interface.

### 2.2 User Classes and Characteristics
*   **Users (Bettors):** Individuals seeking to hedge risks or speculate on event outcomes.
*   **Admin/Market Creators:** Entities responsible for initializing markets and providing initial liquidity.
*   **Chainlink DON (The Engine):** The decentralized network executing the CRE code and providing oracle data.

### 2.3 Design and Implementation Constraints
*   **Sui Object Model:** All markets must be represented as unique programmable objects to maximize parallel execution.
*   **CRE Serverless:** Computation must be stateless within the CRE to maintain $0-cost infrastructure goals.

---

## 3. System Features & Functional Requirements

### 3.1 Market Creation & Management
*   **FR-1.1:** The system shall allow authorized actors to create prediction markets by defining: Event ID, Outcome Space, Expiry Timestamp, and Initial Liquidity.
*   **FR-1.2:** The system shall initialize a "World Table" state for each market group to ensure cross-outcome liquidity efficiency.

### 3.2 Secure Betting (Encrypted Payload)
*   **FR-2.1:** The system shall provide a client-side encryption module to wrap user bets (outcome choice + amount) before submission.
*   **FR-2.2:** The system shall accept encrypted payloads to prevent front-running and "copy-trading" by observers or validators.

### 3.3 Decentralized Batching & AMM Execution (CRE)
*   **FR-3.1:** The Chainlink DON shall collect encrypted bets over a specific epoch (e.g., 2 seconds).
*   **FR-3.2:** The CRE shall decrypt the batch and calculate the new price based on the Joint-Outcome AMM formula (e.g., Logarithmic Market Scoring Rule - LMSR).
*   **FR-3.3:** The CRE shall generate a single "State Update" proof to be submitted to the Sui blockchain, minimizing gas costs.

### 3.4 Automated Settlement & Payout
*   **FR-4.1:** Upon event expiry, the Chainlink DON shall fetch the verifiable outcome from external data providers.
*   **FR-4.2:** The system shall automatically trigger the "Settlement" function in the Move contract to distribute Sui-based assets (SUI/USDC) to winners.

---

## 4. Non-Functional Requirements

### 4.1 Privacy & Security
*   **NFR-1 (Privacy):** User intent must remain hidden until the batch is finalized in the CRE to mitigate MEV (Maximal Extractable Value).
*   **NFR-2 (Integrity):** All computations performed in the CRE must be verifiable via cryptographic signatures from the DON nodes.

### 4.2 Scalability & Performance
*   **NFR-3 (Throughput):** The system shall handle at least 1,000 transactions per second (TPS) via off-chain batching before committing a single transaction to Sui.
*   **NFR-4 (Latency):** The end-to-end execution from bet submission to on-chain confirmation should not exceed 5 seconds.

### 4.3 Cost Efficiency
*   **NFR-5 ($0-Cost Infrastructure):** The system must utilize Chainlink's serverless CRE architecture to avoid the costs of maintaining dedicated backend servers (EC2/GCP).
*   **NFR-6 (Gas Optimization):** By batching transactions, the cost per bet for the user should be reduced by $>90\%$ compared to direct on-chain interaction.

---

## 5. Use Case Diagram

The following diagram illustrates the interaction between the User, the Admin, and the Chainlink CRE nodes within the Sui ecosystem.

```mermaid
usecaseDiagram
    actor "User (Bettor)" as User
    actor "Admin (Market Maker)" as Admin
    actor "Chainlink DON (CRE)" as CRE
    
    package "BanhMiCast System" {
        usecase "Create Market & Provide Liquidity" as UC1
        usecase "Submit Encrypted Bet" as UC2
        usecase "Batch & Execute AMM Math" as UC3
        usecase "Verify Outcome & Settle" as UC4
        usecase "Withdraw Winnings" as UC5
    }

    Admin --> UC1
    User --> UC2
    User --> UC5
    
    UC2 --> CRE : "Encrypted Payload"
    CRE --> UC3 : "Joint-Outcome Math"
    CRE --> UC4 : "Oracle Data Trigger"
    
    UC3 --|> "Sui Blockchain" : "State Update"
    UC4 --|> "Sui Blockchain" : "Payout Distribution"
```

---

## 6. Technical Notes (The "Guru" Perspective)

1.  **On the Joint-Outcome AMM:** By using a World Table, we ensure that a bet *against* "Team A" is mathematically treated as a bet *for* the rest of the pool, preventing the liquidity fragmentation seen in PolyMarket-style binary pairs.
2.  **On Encrypted Batching:** We are implementing a **Threshold Decryption** scheme. No single CRE node can see the user's bet until the batch is closed, ensuring a fair-ordering sequence.
3.  **On Sui Move:** We leverage **Programmable Transaction Blocks (PTB)** to allow users to swap, bet, and stake in a single atomic transaction, significantly enhancing the UX.

---
*End of Document*