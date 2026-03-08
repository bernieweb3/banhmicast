// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BanhMiCastErrors.sol";

/// @title BanhMiCastVerifier — DON Signature Verification Module
/// @notice Validates ECDSA signatures produced by the Chainlink DON
///         before the contract accepts any batch state update.
///         Mirrors the Sui Move `verifier.move` module, adapted from
///         Ed25519 → ECDSA (EVM native via `ecrecover`).
///
/// @dev Security Design:
///   - The DON signer address is stored and can be rotated by the owner.
///   - All calls to `verifyDonSignature` use `ecrecover` to validate
///     that the message was signed by the configured DON signer.
contract BanhMiCastVerifier {
    // =========================================================================
    // State
    // =========================================================================

    /// @notice The contract owner (deployer). Can rotate DON signer.
    address public owner;

    /// @notice The current DON signer address (derived from ECDSA public key).
    address public donSigner;

    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when the DON signer is rotated.
    event DonSignerUpdated(address indexed oldSigner, address indexed newSigner);

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param _donSigner Initial DON signer address.
    constructor(address _donSigner) {
        owner = msg.sender;
        donSigner = _donSigner;
    }

    // =========================================================================
    // Modifiers
    // =========================================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    // =========================================================================
    // Admin: Key Rotation
    // =========================================================================

    /// @notice Replaces the stored DON signer address.
    /// @param _newSigner New DON signer address.
    function setDonSigner(address _newSigner) external onlyOwner {
        if (_newSigner == address(0)) revert InvalidProof();
        address oldSigner = donSigner;
        donSigner = _newSigner;
        emit DonSignerUpdated(oldSigner, _newSigner);
    }

    // =========================================================================
    // Core Verification
    // =========================================================================

    /// @notice Verifies an ECDSA signature over a message hash using the DON's
    ///         stored signer address.
    /// @param messageHash The keccak256 hash of the message that was signed.
    /// @param signature   65-byte ECDSA signature (r, s, v).
    /// @return True if the signature is valid; reverts with InvalidProof() otherwise.
    function verifyDonSignature(
        bytes32 messageHash,
        bytes calldata signature
    ) external view returns (bool) {
        if (signature.length != 65) revert InvalidProof();

        bytes32 ethSignedHash = _toEthSignedMessageHash(messageHash);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        // Normalize v to 27/28
        if (v < 27) v += 27;

        address recovered = ecrecover(ethSignedHash, v, r, s);
        if (recovered == address(0) || recovered != donSigner) revert InvalidProof();

        return true;
    }

    // =========================================================================
    // Internal Helpers
    // =========================================================================

    /// @dev Prepends the Ethereum signed message prefix to a hash.
    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}
