# BanhMiCast Code Convention & Engineering Standards
**Status:** Mandatory for all contributors  
**Version:** 1.0  
**Scope:** Sui Move (On-chain) & Chainlink CRE (Off-chain)

---

## 1. Naming Conventions

### 1.1 Sui Move (On-chain)
Follows the official Rust/Move style guide to ensure interoperability and readability.
*   **Modules:** `snake_case` (e.g., `market_manager.move`).
*   **Functions:** `snake_case` (e.g., `calculate_payout`).
*   **Variables:** `snake_case` (e.g., `remaining_balance`).
*   **Structs:** `PascalCase` (e.g., `WorldTable`).
*   **Constants:** `SCREAMING_SNAKE_CASE` (e.g., `E_INSUFFICIENT_LIQUIDITY`).
*   **Type Parameters:** `PascalCase` (usually single letter like `T`, or descriptive like `AssetType`).

### 1.2 JavaScript / CRE (Off-chain)
Follows standard ECMAScript conventions.
*   **Variables/Functions:** `camelCase` (e.g., `executeLmsrBatch`).
*   **Classes/Interfaces:** `PascalCase` (e.g., `BatchProcessor`).
*   **Constants:** `UPPER_SNAKE_CASE` (e.g., `MAX_BATCH_SIZE`).
*   **Files:** `kebab-case.js` (e.g., `lmsr-engine.js`).

---

## 2. Documentation & Comments

### 2.1 Smart Contract NatSpec (MoveDoc)
Every public function and struct **must** be documented using `///` tags.
```rust
/// Error code for when the market is not yet resolved.
const E_MARKET_NOT_RESOLVED: u64 = 101;

/// @notice Executes the batch settlement for a specific market.
/// @dev Requires a valid signature from the Chainlink DON.
/// @param market: The shared WorldTable object.
/// @param proof: Cryptographic signature from CRE.
public entry fun resolve_batch(market: &mut MarketObject, proof: vector<u8>) {
    // ...
}
```

### 2.2 JavaScript JSDoc
All CRE logic must include JSDoc for complex mathematical functions.
```javascript
/**
 * Calculates the cost function for LMSR.
 * @param {Array<bigint>} shares - Current supply of shares per outcome.
 * @param {number} b - Liquidity sensitivity parameter.
 * @returns {bigint} The calculated cost in MIST.
 */
function calculateCost(shares, b) {
    // ...
}
```

---

## 3. Folder Structure (Monorepo)

To maintain a single source of truth for ABIs and shared types, we use a **Monorepo** structure.

```text
banhmicast/
├── packages/
│   ├── move/               # Sui Move Smart Contracts
│   │   ├── sources/        # .move files
│   │   ├── tests/          # Move Unit Tests
│   │   └── Move.toml
│   ├── cre/                # Chainlink Runtime Environment Scripts
│   │   ├── src/            # JavaScript logic
│   │   ├── tests/          # Jest/Mocha tests
│   │   └── package.json
│   └── shared/             # Shared ABIs, Type Definitions, Constants
├── docs/                   # Technical specifications & SAD
├── scripts/                # Deployment and migration scripts
└── .gitignore
```

---

## 4. Coding Best Practices & Security

### 4.1 Sui Move Specifics
*   **Explicit Errors:** Do not use generic `assert!(condition, 0)`. Use descriptive error constants starting with `E_`.
*   **Balance vs. Coin:** Use `Balance` inside Structs for storage and `Coin` for transaction arguments.
*   **Access Control:** Use the "Cap" (Capability) pattern. Admin functions must require an `&AdminCap` argument.
*   **Object Ownership:** Be explicit about `entry` functions and whether objects are passed by value (consuming them) or by reference.

### 4.2 Chainlink CRE Specifics
*   **Statelessness:** The `executeBatch` script must be deterministic. Avoid `Math.random()` or `Date.now()`. Use epoch timestamps provided by the Oracle trigger.
*   **Financial Precision:** **NEVER** use floating-point numbers (`Number`) for currency. Use `BigInt` or specialized decimal libraries to prevent rounding errors in LMSR math.
*   **Error Handling:** Use `try-catch` blocks to ensure the script returns a meaningful "Revert" reason to the DON if the batch is invalid.

---

## 5. Git Workflow & Commit Messages

### 5.1 Branching Strategy
*   `main`: Production-ready code.
*   `dev`: Integration branch for features.
*   `feature/<name>`: Individual feature development.

### 5.2 Commit Messages (Conventional Commits)
Strict adherence to [Conventional Commits](https://www.conventionalcommits.org/) is required for automated changelog generation.

*   **Format:** `<type>(<scope>): <description>`
*   **Types:**
    *   `feat`: A new feature (e.g., `feat(move): add lmsr math module`).
    *   `fix`: A bug fix (e.g., `fix(cre): handle zero liquidity edge case`).
    *   `docs`: Documentation only changes.
    *   `refactor`: Code change that neither fixes a bug nor adds a feature.
    *   `test`: Adding missing tests.

### 5.3 Pull Request Rules
1.  **Peer Review:** At least one "Approve" from a lead engineer.
2.  **CI/CD:** All `sui move test` and `npm test` must pass before merging.
3.  **Atomic Commits:** Keep PRs small. One PR = One feature/fix.

---

## 6. Auditor's Final Word
> *"Code is read much more often than it is written. Write for the auditor who will look at your code at 3 AM during a mainnet crisis. Clean code is not a luxury; it is our primary security layer."*