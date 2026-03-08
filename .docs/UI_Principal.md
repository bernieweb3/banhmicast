# UI Design System: "Obsidian Crust"

## 1. Visual Foundation

### 1.1 Color Palette (The Cyber-Culinary Contrast)
We use a "Deep Dark" base to minimize eye strain during high-volatility sessions, accented with high-vibrancy "Sui-Cians" and "BanhMi Gold."

*   **Primary (Brand):** `BanhMi Gold (#F2A65A)` — Used for CTAs and highlights. Represents the "golden crust" and value.
*   **Secondary (Tech):** `Sui Cyan (#4CA2FF)` — Used for technical indicators, CRE status, and blockchain-related elements.
*   **Success/Long:** `Hyper-Lime (#B4FF39)` — High-vibrancy green for profit/upward probability.
*   **Danger/Short:** `Electric-Rose (#FF3B6B)` — Sharp pinkish-red for risk/downward probability.
*   **Backgrounds:** `Obsidian (#0A0B0D)` (Base), `Charcoal (#14161A)` (Cards), `Steel (#24272E)` (Borders).

### 1.2 Typography (The Technical Sans)
We need fonts that look like code but read like finance.
*   **Headings:** `Mona Sans` — A powerful, wide-spaced sans-serif for a modern, bold look.
*   **Data/Numbers:** `Geist Mono` — For the "World Table" and price feeds. Monospaced numbers prevent "jumping" UI when values update rapidly.
*   **Body:** `Inter` — The industry standard for readability in dense DeFi interfaces.

### 1.3 Layout System (The "Modular Grid")
*   **Bento-Box Grid:** Every element (Orderbook, Chart, World Table) is a modular card with a `1px` border (`Steel`).
*   **Spatial Depth:** Use inner-glows instead of drop shadows to simulate a "Control Center" embedded in glass.

---

## 2. Data Visualization: The World Table (Joint-Outcome Matrix)

Visualizing $2^N$ outcomes (where outcomes of different events are linked) requires **nested hierarchies** to prevent cognitive overload.

### 2.1 The "Ribbon of Probability"
Instead of a flat list, use a **Weighted Horizontal Stack**. 
*   **Logic:** Every event outcome is a block in the stack. The width of the block represents its probability (0-100%).
*   **Joint Visualization:** When a user selects a combination (e.g., "Team A wins" + "Gas < 20 gwei"), the UI highlights the **Intersection** of these ribbons, dimming the rest.

### 2.2 The "Probability Heat-Grid"
For the World Table matrix:
*   **Cell Intensity:** Use background opacity based on probability. High-probability cells glow with `BanhMi Gold` at 20% opacity.
*   **Delta Indicators:** Small, floating `+` or `-` indicators next to prices that fade in/out when the CRE updates a batch, showing "Pressure" in the market.

---

## 3. Component States & Web3 Wallet Interactions

In BanhMiCast, the "Sign" action is unique because it initiates an **Encrypted Commitment**.

### 3.1 Button & Wallet Sign States
| State | Visual Treatment | Meaning |
| :--- | :--- | :--- |
| **Default** | `Gold` background, black text. High contrast. | Ready to trade. |
| **Hover** | `Gold` glow effect (box-shadow: 0 0 15px #F2A65A). | Action intent confirmed. |
| **Active (Click)** | Scaled down to 98%, background shifts to `Sui Cyan`. | Wallet handshake initiated. |
| **Wallet Signing** | Pulsing border. Text changes to *"Check Wallet..."* | Awaiting L1 commitment. |
| **Processing (CRE)** | Shimmer effect (Skeleton loading) across the card. | Off-chain batching in progress. |
| **Disabled** | 40% Opacity, `Grayscale` filter. | Insufficient balance or Market Closed. |

### 3.2 The "Encryption Shield" Animation
When a user signs, a **Shield Icon Overlay** briefly appears over the "Place Bet" button.
*   **Visual:** Hexagonal particles collapse into the button.
*   **Purpose:** To visually communicate that the payload is being **encrypted** before leaving the browser, reinforcing the "Privacy" principle.

---

## 4. UI Standards for "Trust"

1.  **Verifiable Badges:** Every price update from the CRE should have a tiny "Chainlink" logo next to it. Hovering reveals the **Batch ID** and **Proof Link**.
2.  **Slippage Tolerance Bar:** A sleek, minimal slider that changes from `Cyan` (Safe) to `Rose` (Aggressive) as the user increases their slippage tolerance.
3.  **Real-Time "Liveness" Dot:** A small green blinking dot in the header labeled "CRE Syncing," indicating the off-chain engine is healthy.

---

## 5. Summary Quote
> *"We don't just show data; we show the **certainty of the uncertain**. By using Obsidian-Dark surfaces and Gold-Light data points, we turn a prediction market into a high-precision instrument."*