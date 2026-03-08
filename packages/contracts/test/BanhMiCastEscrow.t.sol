// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/BanhMiCastVerifier.sol";
import "../src/BanhMiCastMarket.sol";
import "../src/BanhMiCastEscrow.sol";

/// @title BanhMiCastEscrow Tests
/// @notice Mirrors the Sui Move `escrow_tests.move` test suite.
contract BanhMiCastEscrowTest is Test {
    BanhMiCastVerifier verifier;
    BanhMiCastMarket marketContract;
    BanhMiCastEscrow escrow;

    address admin = address(0xAD);
    address userA = address(0xA1);

    uint256 constant DON_PRIVATE_KEY = 0xBEEF;
    address donSigner;

    function setUp() public {
        donSigner = vm.addr(DON_PRIVATE_KEY);

        // Fund accounts BEFORE deploying (admin needs ETH for createMarket)
        vm.deal(admin, 100 ether);
        vm.deal(userA, 10 ether);

        vm.startPrank(admin);
        verifier = new BanhMiCastVerifier(donSigner);
        marketContract = new BanhMiCastMarket(address(verifier));
        escrow = new BanhMiCastEscrow(address(marketContract));

        // Create a default 2-outcome market with 1 ETH liquidity
        marketContract.createMarket{value: 1 ether}("test_cid", 2, 10_000);
        vm.stopPrank();
    }

    // =========================================================================
    // Test: commitBet — success
    // =========================================================================

    function test_commitBet_success() public {
        vm.prank(userA);
        escrow.commitBet{value: 0.005 ether}(
            1, // marketId
            "encrypted-payload-123",
            keccak256("test-data")
        );

        (address commitOwner, uint256 mktId, bytes32 hash, uint256 collateral, uint256 ts, bool exists) =
            escrow.getCommitment(1);

        assertEq(commitOwner, userA);
        assertEq(mktId, 1);
        assertEq(hash, keccak256("test-data"));
        assertEq(collateral, 0.005 ether);
        assertTrue(ts > 0);
        assertTrue(exists);
    }

    // =========================================================================
    // Test: commitBet — revert if market is closed
    // =========================================================================

    function test_commitBet_revert_marketClosed() public {
        // Resolve the market first
        vm.prank(admin);
        marketContract.resolveMarket(1, 0);

        vm.prank(userA);
        vm.expectRevert(MarketClosed.selector);
        escrow.commitBet{value: 0.005 ether}(
            1,
            "blob",
            keccak256("data")
        );
    }

    // =========================================================================
    // Test: commitBet — revert if payment below minimum
    // =========================================================================

    function test_commitBet_revert_insufficientFunds() public {
        vm.prank(userA);
        vm.expectRevert(InsufficientFunds.selector);
        escrow.commitBet{value: 0.0009 ether}( // below MIN_BET_WEI (0.001 ETH)
            1,
            "blob",
            keccak256("data")
        );
    }

    // =========================================================================
    // Test: commitBet — revert if commitment hash is zero
    // =========================================================================

    function test_commitBet_revert_invalidHash() public {
        vm.prank(userA);
        vm.expectRevert(InvalidHash.selector);
        escrow.commitBet{value: 0.005 ether}(
            1,
            "blob",
            bytes32(0) // zero hash
        );
    }

    // =========================================================================
    // Test: commitBet — revert if blob_id is empty
    // =========================================================================

    function test_commitBet_revert_emptyBlobId() public {
        vm.prank(userA);
        vm.expectRevert(EmptyBlobId.selector);
        escrow.commitBet{value: 0.005 ether}(
            1,
            "", // empty blob ID
            keccak256("data")
        );
    }

    // =========================================================================
    // Test: emergencyRefund — success after grace period
    // =========================================================================

    function test_emergencyRefund_afterTimeout() public {
        // Commit a bet
        vm.prank(userA);
        escrow.commitBet{value: 0.005 ether}(
            1,
            "blob-id",
            keccak256("data")
        );

        uint256 balanceBefore = userA.balance;

        // Warp past grace period (30 minutes + 1 minute)
        vm.warp(block.timestamp + 31 minutes);

        vm.prank(userA);
        escrow.emergencyRefund(1);

        // Check refund
        assertEq(userA.balance, balanceBefore + 0.005 ether);

        // Check commitment is deleted
        (, , , , , bool exists) = escrow.getCommitment(1);
        assertFalse(exists);
    }

    // =========================================================================
    // Test: emergencyRefund — revert before grace period
    // =========================================================================

    function test_emergencyRefund_revert_tooEarly() public {
        // Commit a bet
        vm.prank(userA);
        escrow.commitBet{value: 0.005 ether}(
            1,
            "blob-id",
            keccak256("data")
        );

        // Warp only 1 minute — too early
        vm.warp(block.timestamp + 1 minutes);

        vm.prank(userA);
        vm.expectRevert(GracePeriodNotElapsed.selector);
        escrow.emergencyRefund(1);
    }

    // =========================================================================
    // Test: emergencyRefund — revert if not owner
    // =========================================================================

    function test_emergencyRefund_revert_notOwner() public {
        vm.prank(userA);
        escrow.commitBet{value: 0.005 ether}(
            1,
            "blob-id",
            keccak256("data")
        );

        vm.warp(block.timestamp + 31 minutes);

        // Try refund as admin (not the owner of the commitment)
        vm.prank(admin);
        vm.expectRevert(NotAuthorized.selector);
        escrow.emergencyRefund(1);
    }
}
