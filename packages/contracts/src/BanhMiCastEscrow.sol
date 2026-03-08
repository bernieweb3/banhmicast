// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BanhMiCastErrors.sol";
import "./BanhMiCastMarket.sol";

/// @title BanhMiCastEscrow — Encrypted Bet Commitment Module
/// @notice Handles user bet commitments ("Encrypted Batching") and emergency refunds.
///         Mirrors the Sui Move `escrow.move` module.
///
/// @dev Design:
///   - `commitBet` creates a BetCommitment record.  The commitment stores only
///     the *hash* and the *encrypted payload CID* — never the plaintext direction.
///   - Collateral is locked as ETH until the CRE processes the batch.
///   - `emergencyRefund` unwinds a stale commitment after the grace period,
///     protecting users if the Chainlink DON becomes unresponsive.
contract BanhMiCastEscrow {
    // =========================================================================
    // Constants
    // =========================================================================

    /// @notice Minimum bet in wei (0.001 ETH = 1e15 wei).
    uint256 public constant MIN_BET_WEI = 1e15;

    /// @notice Grace period before emergency refund is allowed (30 minutes).
    uint256 public constant GRACE_PERIOD = 30 minutes;

    // =========================================================================
    // State
    // =========================================================================

    /// @notice Reference to the Market contract (to check isActive).
    BanhMiCastMarket public marketContract;

    /// @notice Auto-incrementing commitment ID counter.
    uint256 public nextCommitmentId;

    // =========================================================================
    // Structs
    // =========================================================================

    /// @notice Represents a user's "intent" — collateral locked, bet direction hidden.
    struct BetCommitment {
        address owner;
        uint256 marketId;
        string encryptedPayloadCid;   // Encrypted payload CID
        bytes32 commitmentHash;       // keccak256(outcomeIndex || amount)
        uint256 collateralLocked;     // ETH in wei
        uint256 timestampLocked;      // block.timestamp when created
        bool exists;
    }

    // =========================================================================
    // Storage
    // =========================================================================

    /// @notice commitmentId => BetCommitment.
    mapping(uint256 => BetCommitment) public commitments;

    /// @notice owner => array of commitment IDs (for enumeration).
    mapping(address => uint256[]) public userCommitmentIds;

    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when a user creates an encrypted bet commitment.
    event BetCommitted(
        uint256 indexed commitmentId,
        uint256 indexed marketId,
        address indexed owner,
        uint256 collateralWei,
        uint256 timestampLocked
    );

    /// @notice Emitted when a user reclaims collateral after a liveness failure.
    event EmergencyRefund(
        uint256 indexed commitmentId,
        uint256 indexed marketId,
        address indexed owner,
        uint256 refundWei
    );

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param _marketContract Address of the BanhMiCastMarket contract.
    constructor(address _marketContract) {
        marketContract = BanhMiCastMarket(payable(_marketContract));
        nextCommitmentId = 1;
    }

    // =========================================================================
    // commit_bet
    // =========================================================================

    /// @notice Locks user collateral and records the encrypted bet commitment.
    ///
    /// @dev The commitment does NOT reveal the outcome direction — only the
    ///      encrypted payload CID and the keccak256 hash of the plaintext.
    ///
    /// @param marketId          Target market ID.
    /// @param encryptedPayloadCid CID of the encrypted payload.
    /// @param commitmentHash    keccak256(outcomeIndex || amount) — exactly 32 bytes.
    function commitBet(
        uint256 marketId,
        string calldata encryptedPayloadCid,
        bytes32 commitmentHash
    ) external payable {
        // Guard: market must be open.
        if (!marketContract.isActive(marketId)) revert MarketClosed();

        // Guard: minimum bet.
        if (msg.value < MIN_BET_WEI) revert InsufficientFunds();

        // Guard: commitment hash must not be zero (equivalent of 32-byte check).
        if (commitmentHash == bytes32(0)) revert InvalidHash();

        // Guard: blob ID must not be empty.
        if (bytes(encryptedPayloadCid).length == 0) revert EmptyBlobId();

        uint256 commitmentId = nextCommitmentId++;

        commitments[commitmentId] = BetCommitment({
            owner: msg.sender,
            marketId: marketId,
            encryptedPayloadCid: encryptedPayloadCid,
            commitmentHash: commitmentHash,
            collateralLocked: msg.value,
            timestampLocked: block.timestamp,
            exists: true
        });

        userCommitmentIds[msg.sender].push(commitmentId);

        emit BetCommitted(
            commitmentId,
            marketId,
            msg.sender,
            msg.value,
            block.timestamp
        );
    }

    // =========================================================================
    // emergency_refund
    // =========================================================================

    /// @notice Reclaims locked collateral if the DON has failed to process
    ///         the batch within the grace period (30 minutes).
    ///
    /// @dev This is the "Liveness Failure" safety net from TDD Section 4.
    ///
    /// @param commitmentId ID of the user's BetCommitment.
    function emergencyRefund(uint256 commitmentId) external {
        BetCommitment storage commitment = commitments[commitmentId];

        // Guard: commitment must exist.
        if (!commitment.exists) revert InvalidHash();

        // Guard: only the owner can refund.
        if (commitment.owner != msg.sender) revert NotAuthorized();

        // Guard: grace period must have elapsed.
        if (block.timestamp < commitment.timestampLocked + GRACE_PERIOD) {
            revert GracePeriodNotElapsed();
        }

        uint256 refundWei = commitment.collateralLocked;
        uint256 marketId = commitment.marketId;
        address refundOwner = commitment.owner;

        // Destroy the commitment (equivalent of object::delete in Move).
        delete commitments[commitmentId];

        // Return collateral to the owner.
        (bool success, ) = refundOwner.call{value: refundWei}("");
        require(success, "ETH refund failed");

        emit EmergencyRefund(commitmentId, marketId, refundOwner, refundWei);
    }

    // =========================================================================
    // Getters
    // =========================================================================

    function getCommitment(uint256 commitmentId) external view returns (
        address commitOwner,
        uint256 marketId,
        bytes32 commitHash,
        uint256 collateralWei,
        uint256 timestampLocked,
        bool exists_
    ) {
        BetCommitment storage c = commitments[commitmentId];
        return (c.owner, c.marketId, c.commitmentHash, c.collateralLocked, c.timestampLocked, c.exists);
    }

    function getUserCommitmentIds(address user) external view returns (uint256[] memory) {
        return userCommitmentIds[user];
    }

    /// @notice Allows contract to receive ETH.
    receive() external payable {}
}
