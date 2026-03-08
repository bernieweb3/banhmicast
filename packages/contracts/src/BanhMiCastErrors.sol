// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title BanhMiCastErrors — Custom Error Library
/// @notice All application-level errors used across the BanhMiCast contracts.
///         Gas-efficient custom errors replace revert strings.
///         Mirrors the error taxonomy from the original Sui Move `errors.move`.

// =========================================================================
// Market Lifecycle Errors (1xx)
// =========================================================================

/// @notice Market is not accepting new bets (closed or resolved).
error MarketClosed();

/// @notice Market has not been resolved yet; cannot claim payout.
error MarketNotResolved();

/// @notice Market is already resolved; cannot resolve again.
error MarketAlreadyResolved();

/// @notice Invalid number of outcomes (must be >= 2).
error InvalidOutcomesCount();

// =========================================================================
// Bet / Commitment Errors (2xx)
// =========================================================================

/// @notice Collateral amount is below the minimum bet threshold.
error InsufficientFunds();

/// @notice Commitment hash length is not 32 bytes (keccak256 output).
error InvalidHash();

/// @notice Outstanding bet commitment blob_id is empty.
error EmptyBlobId();

/// @notice Emergency refund attempted before the grace period has elapsed.
error GracePeriodNotElapsed();

/// @notice User position does not match the winning outcome.
error WrongOutcome();

// =========================================================================
// CRE / Batch Errors (3xx)
// =========================================================================

/// @notice The DON signature over the batch payload is invalid.
error InvalidProof();

/// @notice Batch ID is not the expected next sequential value (replay protection).
error OutOfSequence();

/// @notice The number of allocations doesn't match the batch commitment count.
error BatchSizeMismatch();

/// @notice Price impact of the batch exceeds the configured slippage guard.
error SlippageExceeded();

/// @notice Liquidity parameter `b` cannot be zero.
error InsufficientLiquidity();

// =========================================================================
// Access Control Errors (4xx)
// =========================================================================

/// @notice Caller does not hold the required admin role.
error NotAuthorized();
