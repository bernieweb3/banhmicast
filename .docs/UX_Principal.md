# UX Principal System for BanhMiCast

## 1. Screen: Home / Market Explorer
**Goal:** High-level overview of available liquidity pools and active events.

### [Header]
*   **Logo:** BanhMiCast (Icon: A stylized, golden geometric baguette).
*   **Nav:** [Explore] [My Portfolio] [Leaderboard] [Docs].
*   **Network Status:** Green Dot • "CRE Node: Active" (Hover for latency details).
*   **Wallet:** [Connect Wallet] or [0x...6a81 | 120.5 SUI].

### [Hero Section]
*   **Headline:** "The Future is Parallel. Predict it with Privacy."
*   **Sub-headline:** Joint-outcome liquidity for smarter hedging. Powered by Sui & Chainlink CRE.

### [Active World Tables Grid]
*Each card represents a unified liquidity pool containing multiple linked events.*
*   **Card Title:** "Global Macro & Election Matrix" (e.g., US Election + Fed Rate Hike).
*   **Status Badge:** [High Liquidity] [Ends in 14h:20m].
*   **Mini-Probability Map:** A small 2x2 grid showing the heat of different outcome combinations.
*   **Quick Stats:** Total Volume: $1.2M | Shared Liquidity (b): 50,000.
*   **CTA Button:** [Enter Market].

---

## 2. Screen: Betting Interface (The "War Room")
**Goal:** Facilitate complex decision-making with a simple, secure execution flow.

### [Layout: Left Column - Context]
*   **Market Header:** "US Election & Interest Rate Outcome."
*   **Price Chart:** Candlestick chart showing the probability shift of the *selected* outcome combination over time.

### [Layout: Center - The World Table (Selection Matrix)]
*   **The Grid:** Columns (Event A: Win/Loss) x Rows (Event B: Up/Down).
*   **Cell Interaction:**
    *   **Inactive:** Displays "Current Price" (e.g., 0.25 SUI).
    *   **Selected:** Cell glows with a `BanhMi Gold` border. Shows "Projected Return" (e.g., 4.0x).
    *   **Tooltip:** "Betting on this outcome adds liquidity to the entire table."

### [Layout: Right Column - Betting Panel]
*   **Panel Title:** "Secure Order Entry."
*   **Asset Selector:** [SUI] [USDC].
*   **Input Field:** [ 100 ] Max.
*   **Trade Metrics (Auto-calculated via CRE preview):**
    *   **Potential Payout:** 400.00 SUI.
    *   **Price Impact:** < 0.05% (Calculated via LMSR).
    *   **Slippage Tolerance:** [0.5%] (Settings Gear icon).
*   **The Privacy Shield:** A small toggle (default ON): "Encrypted Batching Enabled" (Tooltip: Your bet is hidden from bots until the batch executes).
*   **CTA Button:**
    *   **Label:** [ ENCRYPT & SUBMIT ORDER ]
    *   **Sub-text:** "Commitment gas: ~0.001 SUI."

---

## 3. Transaction Flow & Feedback (The "Wait" UX)

Since we use **Encrypted Batching**, the user experience doesn't end at the click; it begins.

### [Step 1: Wallet Interaction]
*   **Toast (Info):** "Awaiting Signature... Please confirm the commitment in your wallet."
*   **UX Note:** The wallet only sees a hash. The UI explains: "You are signing a cryptographic commitment of your bet."

### [Step 2: Processing (The CRE Gap)]
*   **Modal Overlay (Non-intrusive):** 
    *   **Icon:** An animated shield pulsing with binary data.
    *   **Headline:** "Securing Your Bet."
    *   **Status Message:** "Your order is being batched off-chain by the Chainlink DON. This prevents front-running and ensures the best LMSR price."
    *   **Progress Bar:** [|||||||||||||||||   ] (Syncing with Batch #9928).

### [Step 3: Success Feedback]
*   **Toast (Success):** "Order Executed! Batch #9928 Finalized."
*   **Action Link:** [View Proof on SuiScan] [View Your Position].
*   **Feedback Message:** "100 SUI successfully committed. You now own 400.2 Outcome-A Shares."

---

## 4. UX Writing: Error Handling & System States

| Scenario | UX Message (Heading) | Body Text |
| :--- | :--- | :--- |
| **Slippage Exceeded** | "Price Shift Detected" | "The batch price moved beyond your 0.5% tolerance. Your collateral has been safely returned to your wallet." |
| **CRE Offline** | "Engine on Standby" | "The Chainlink CRE is currently out of sync. You can still place 'Open Commitments' or try again in a few minutes." |
| **Market Resolved** | "The Future is Here" | "This event has been resolved. You have **400 SUI** waiting for you. [Claim Now]" |

---

## 5. Micro-Copy Principles for BanhMiCast
1.  **Avoid "Bet":** Use "Invest," "Position," or "Predict" to align with the DeFi professional audience.
2.  **Explain "Encrypted":** Always pair encryption with the benefit: "Privacy-guaranteed" or "Bot-protected."
3.  **World Table Clarity:** Use "Shared Liquidity" instead of "Joint-Outcome AMM" to explain why prices are more stable.