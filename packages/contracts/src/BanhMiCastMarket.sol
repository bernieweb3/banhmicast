// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BanhMiCastErrors.sol";
import "./BanhMiCastVerifier.sol";

/// @title BanhMiCastMarket — Core Market Module ("Truth Layer")
/// @notice The Solidity equivalent of the Sui Move `market.move`.
///         Manages:
///           - Market creation ("World Table" AMM state)
///           - CRE batch resolution with DON-signed state updates
///           - Market resolution & payout claims
///
/// @dev Security Properties (from TDD):
///   1. All state-mutating functions require owner or valid DON signature.
///   2. Batch IDs are sequential; replay attacks cause OutOfSequence revert.
///   3. Slippage guard (maxPriceImpactBps) protects against manipulation.
contract BanhMiCastMarket {
    // =========================================================================
    // Constants
    // =========================================================================

    /// @notice Basis-point denominator (10_000 = 100%).
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Default maximum allowed price impact per batch (5% = 500 bps).
    uint256 public constant DEFAULT_MAX_PRICE_IMPACT_BPS = 500;

    // =========================================================================
    // State
    // =========================================================================

    /// @notice Contract owner (deployer) — equivalent of AdminCap in Move.
    address public owner;

    /// @notice Reference to the DON signature verifier contract.
    BanhMiCastVerifier public verifier;

    /// @notice Auto-incrementing market ID counter.
    uint256 public nextMarketId;

    /// @notice Auto-incrementing user position ID counter.
    uint256 public nextPositionId;

    // =========================================================================
    // Structs
    // =========================================================================

    /// @notice The "World Table" — on-chain state for a prediction market.
    ///         Equivalent of MarketObject shared object in Move.
    struct Market {
        address creator;
        string descriptionCid;
        uint256 outcomesCount;
        uint256 liquidityB;
        uint256 vaultBalance;        // ETH locked in wei (replaces Balance<SUI>)
        bool isActive;
        uint256 lastBatchId;
        uint256 winningOutcome;
        uint256 maxPriceImpactBps;
        bool exists;                 // Existence flag for mapping-based storage
    }

    /// @notice A user's share of a specific outcome.
    ///         Equivalent of UserPosition owned object in Move.
    struct UserPosition {
        address owner;
        uint256 marketId;
        uint256 outcomeIndex;
        uint256 shareBalance;
        bool exists;
    }

    /// @notice Per-user allocation within a batch result payload (from CRE).
    struct UserAllocation {
        address user;
        uint256 sharesMinted;
        uint256 outcomeIndex;
    }

    // =========================================================================
    // Storage Mappings
    // =========================================================================

    /// @notice marketId => Market state.
    mapping(uint256 => Market) public markets;

    /// @notice marketId => outcomeIndex => totalShares.
    mapping(uint256 => mapping(uint256 => uint256)) public sharesSupply;

    /// @notice marketId => outcomeIndex => scaledPrice (1_000_000 = 100%).
    mapping(uint256 => mapping(uint256 => uint256)) public currentPrices;

    /// @notice positionId => UserPosition.
    mapping(uint256 => UserPosition) public positions;

    /// @notice owner => array of position IDs (for enumeration).
    mapping(address => uint256[]) public userPositionIds;

    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when a new market is created.
    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        uint256 outcomesCount,
        uint256 liquidityB
    );

    /// @notice Emitted when the CRE successfully resolves a batch.
    event BatchResolved(
        uint256 indexed marketId,
        uint256 indexed batchId,
        uint256 numAllocations
    );

    /// @notice Emitted when a market is resolved to a winning outcome.
    event MarketResolved(
        uint256 indexed marketId,
        uint256 winningOutcome
    );

    /// @notice Emitted when a winning position is claimed.
    event PayoutClaimed(
        uint256 indexed marketId,
        address indexed user,
        uint256 outcomeIndex,
        uint256 payoutWei
    );

    /// @notice Emitted when a UserPosition is created via batch resolution.
    event PositionCreated(
        uint256 indexed positionId,
        uint256 indexed marketId,
        address indexed owner,
        uint256 outcomeIndex,
        uint256 shareBalance
    );

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param _verifier Address of the BanhMiCastVerifier contract.
    constructor(address _verifier) {
        owner = msg.sender;
        verifier = BanhMiCastVerifier(_verifier);
        nextMarketId = 1;
        nextPositionId = 1;
    }

    // =========================================================================
    // Modifiers
    // =========================================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    // =========================================================================
    // create_market
    // =========================================================================

    /// @notice Creates a new prediction market. Owner-only (AdminCap equivalent).
    /// @param descriptionCid CID for market metadata.
    /// @param outcomesCount  Number of mutually exclusive outcomes (>= 2).
    /// @param liquidityB     LMSR `b` parameter (sensitivity; fixed for lifetime).
    function createMarket(
        string calldata descriptionCid,
        uint256 outcomesCount,
        uint256 liquidityB
    ) external payable onlyOwner {
        if (outcomesCount < 2) revert InvalidOutcomesCount();
        if (liquidityB == 0) revert InsufficientLiquidity();

        uint256 marketId = nextMarketId++;

        markets[marketId] = Market({
            creator: msg.sender,
            descriptionCid: descriptionCid,
            outcomesCount: outcomesCount,
            liquidityB: liquidityB,
            vaultBalance: msg.value,
            isActive: true,
            lastBatchId: 0,
            winningOutcome: 0,
            maxPriceImpactBps: DEFAULT_MAX_PRICE_IMPACT_BPS,
            exists: true
        });

        // Initialise shares_supply and uniform prices.
        uint256 unitPrice = 1_000_000 / outcomesCount;
        for (uint256 i = 0; i < outcomesCount; i++) {
            sharesSupply[marketId][i] = 0;
            currentPrices[marketId][i] = unitPrice;
        }

        emit MarketCreated(marketId, msg.sender, outcomesCount, liquidityB);
    }

    // =========================================================================
    // resolve_batch_with_cre  ⚠️ SECURITY CRITICAL
    // =========================================================================

    /// @notice The primary entry point for the Chainlink DON to update market state.
    ///
    /// @dev Security Checklist (must all pass before state mutation):
    ///   ① Market must be active.
    ///   ② Batch ID must be exactly lastBatchId + 1 (no replay, no skip).
    ///   ③ newSharesSupply length == outcomesCount.
    ///   ④ priceUpdates length == outcomesCount.
    ///   ⑤ ECDSA signature verification via Verifier.
    ///   ⑥ Maximum price impact per outcome within maxPriceImpactBps.
    ///
    /// @param marketId         Target market ID.
    /// @param batchId          Sequential batch identifier.
    /// @param newSharesSupply  New shares supply per outcome after this batch.
    /// @param priceUpdates     New prices per outcome (scaled by 1_000_000).
    /// @param allocations      Per-user allocations from the CRE.
    /// @param signature        65-byte ECDSA signature from the DON.
    function resolveBatchWithCre(
        uint256 marketId,
        uint256 batchId,
        uint256[] calldata newSharesSupply,
        uint256[] calldata priceUpdates,
        UserAllocation[] calldata allocations,
        bytes calldata signature
    ) external {
        Market storage market = markets[marketId];

        // ① Market must be active.
        if (!market.isActive) revert MarketClosed();

        // ② Sequence check — prevents replay attacks.
        if (market.lastBatchId + 1 != batchId) revert OutOfSequence();

        // ③ Shape validation — new shares supply must cover all outcomes.
        if (newSharesSupply.length != market.outcomesCount) revert BatchSizeMismatch();

        // ④ Price updates must cover all outcomes.
        if (priceUpdates.length != market.outcomesCount) revert BatchSizeMismatch();

        // ⑤ Signature verification — aborts with InvalidProof if invalid.
        bytes32 messageHash = keccak256(abi.encodePacked(batchId));
        verifier.verifyDonSignature(messageHash, signature);

        // ⑥ Slippage guard — check max price impact per outcome.
        for (uint256 k = 0; k < market.outcomesCount; k++) {
            uint256 oldPrice = currentPrices[marketId][k];
            uint256 newPrice = priceUpdates[k];
            if (oldPrice > 0) {
                uint256 diff = newPrice > oldPrice
                    ? newPrice - oldPrice
                    : oldPrice - newPrice;
                uint256 impactBps = (diff * BPS_DENOMINATOR) / oldPrice;
                if (impactBps > market.maxPriceImpactBps) revert SlippageExceeded();
            }
        }

        // =========================================================
        // State Mutations (only reached after all guards pass)
        // =========================================================

        // Update shares supply.
        for (uint256 s = 0; s < market.outcomesCount; s++) {
            sharesSupply[marketId][s] = newSharesSupply[s];
        }

        // Update cached prices.
        for (uint256 p = 0; p < market.outcomesCount; p++) {
            currentPrices[marketId][p] = priceUpdates[p];
        }

        // Advance batch counter.
        market.lastBatchId = batchId;

        // Mint UserPosition objects for each allocation.
        for (uint256 a = 0; a < allocations.length; a++) {
            uint256 positionId = nextPositionId++;
            positions[positionId] = UserPosition({
                owner: allocations[a].user,
                marketId: marketId,
                outcomeIndex: allocations[a].outcomeIndex,
                shareBalance: allocations[a].sharesMinted,
                exists: true
            });
            userPositionIds[allocations[a].user].push(positionId);

            emit PositionCreated(
                positionId,
                marketId,
                allocations[a].user,
                allocations[a].outcomeIndex,
                allocations[a].sharesMinted
            );
        }

        emit BatchResolved(marketId, batchId, allocations.length);
    }

    // =========================================================================
    // resolve_market
    // =========================================================================

    /// @notice Resolves a market to a definitive winning outcome. Owner-only.
    /// @param marketId       Target market ID.
    /// @param winningOutcome Zero-based index of the winning outcome.
    function resolveMarket(
        uint256 marketId,
        uint256 winningOutcome
    ) external onlyOwner {
        Market storage market = markets[marketId];
        if (!market.isActive) revert MarketAlreadyResolved();
        if (winningOutcome >= market.outcomesCount) revert WrongOutcome();

        market.isActive = false;
        market.winningOutcome = winningOutcome;

        emit MarketResolved(marketId, winningOutcome);
    }

    // =========================================================================
    // claim_payout
    // =========================================================================

    /// @notice Burns a winning UserPosition and transfers pro-rata ETH payout.
    ///
    /// @dev Payout formula:
    ///   payout = (position.shareBalance / totalWinningShares) * vaultBalance
    ///
    /// @param positionId ID of the caller's UserPosition.
    function claimPayout(uint256 positionId) external {
        UserPosition storage position = positions[positionId];
        if (!position.exists) revert WrongOutcome();
        if (position.owner != msg.sender) revert NotAuthorized();

        Market storage market = markets[position.marketId];

        // Market must be resolved.
        if (market.isActive) revert MarketNotResolved();

        // Position must be on the winning outcome.
        if (position.outcomeIndex != market.winningOutcome) revert WrongOutcome();

        // Calculate pro-rata payout.
        uint256 totalWinningShares = sharesSupply[position.marketId][market.winningOutcome];
        uint256 vaultBal = market.vaultBalance;

        uint256 payoutWei = 0;
        if (totalWinningShares > 0) {
            payoutWei = (uint256(position.shareBalance) * vaultBal) / totalWinningShares;
        }

        uint256 outcomeIndex = position.outcomeIndex;
        uint256 mktId = position.marketId;

        // Destroy the position (equivalent of object::delete in Move).
        delete positions[positionId];

        // Transfer payout from vault.
        if (payoutWei > 0) {
            market.vaultBalance -= payoutWei;
            (bool success, ) = msg.sender.call{value: payoutWei}("");
            require(success, "ETH transfer failed");
        }

        emit PayoutClaimed(mktId, msg.sender, outcomeIndex, payoutWei);
    }

    // =========================================================================
    // Deposit collateral (from Escrow or direct)
    // =========================================================================

    /// @notice Allows the Escrow contract (or anyone) to deposit collateral
    ///         into a market's vault. Used when processing bet commitments.
    /// @param marketId Target market.
    function depositCollateral(uint256 marketId) external payable {
        Market storage market = markets[marketId];
        if (!market.exists) revert MarketClosed();
        market.vaultBalance += msg.value;
    }

    // =========================================================================
    // Getters
    // =========================================================================

    function isActive(uint256 marketId) external view returns (bool) {
        return markets[marketId].isActive;
    }

    function outcomesCount(uint256 marketId) external view returns (uint256) {
        return markets[marketId].outcomesCount;
    }

    function liquidityB(uint256 marketId) external view returns (uint256) {
        return markets[marketId].liquidityB;
    }

    function lastBatchId(uint256 marketId) external view returns (uint256) {
        return markets[marketId].lastBatchId;
    }

    function winningOutcome(uint256 marketId) external view returns (uint256) {
        return markets[marketId].winningOutcome;
    }

    function vaultBalance(uint256 marketId) external view returns (uint256) {
        return markets[marketId].vaultBalance;
    }

    function getSharesForOutcome(uint256 marketId, uint256 outcomeIndex) external view returns (uint256) {
        return sharesSupply[marketId][outcomeIndex];
    }

    function getCurrentPrice(uint256 marketId, uint256 outcomeIndex) external view returns (uint256) {
        return currentPrices[marketId][outcomeIndex];
    }

    function getPosition(uint256 positionId) external view returns (
        address posOwner,
        uint256 marketId,
        uint256 outcomeIndex,
        uint256 shareBalance,
        bool exists_
    ) {
        UserPosition storage pos = positions[positionId];
        return (pos.owner, pos.marketId, pos.outcomeIndex, pos.shareBalance, pos.exists);
    }

    /// @notice Allows contract to receive ETH.
    receive() external payable {}
}
