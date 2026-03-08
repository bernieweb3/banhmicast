// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/BanhMiCastVerifier.sol";
import "../src/BanhMiCastMarket.sol";
import "../src/BanhMiCastEscrow.sol";

/// @title BanhMiCast Integration Tests
/// @notice Mirrors the Sui Move `integration_tests.move` — full lifecycle flow.
///
///   create_market → commit_bet (x2 users) → resolveBatchWithCre →
///   resolveMarket → claimPayout
///
/// Also tests resolve_batch security guards (replay, shape mismatch).
contract BanhMiCastIntegrationTest is Test {
    BanhMiCastVerifier verifier;
    BanhMiCastMarket marketContract;
    BanhMiCastEscrow escrow;

    address admin = address(0xAD);
    address userA = address(0xA1);
    address userB = address(0xB2);

    // Deterministic DON keypair for testing (via Foundry vm.sign)
    uint256 constant DON_PRIVATE_KEY = 0xBEEF;
    address donSigner;

    function setUp() public {
        donSigner = vm.addr(DON_PRIVATE_KEY);

        vm.startPrank(admin);
        verifier = new BanhMiCastVerifier(donSigner);
        marketContract = new BanhMiCastMarket(address(verifier));
        escrow = new BanhMiCastEscrow(address(marketContract));
        vm.stopPrank();

        // Fund test accounts
        vm.deal(admin, 100 ether);
        vm.deal(userA, 10 ether);
        vm.deal(userB, 10 ether);
    }

    // =========================================================================
    // Helper: Sign a batch_id with the DON key (produces valid ECDSA sig)
    // =========================================================================

    function _signBatchId(uint256 batchId) internal pure returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encodePacked(batchId));
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DON_PRIVATE_KEY, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    // Helper: create default 2-outcome market
    function _createMarketAndCommitBets() internal returns (uint256 marketId) {
        vm.prank(admin);
        marketContract.createMarket{value: 10 ether}(
            "integration_test_cid",
            2,
            100_000
        );
        marketId = 1;

        vm.prank(userA);
        escrow.commitBet{value: 0.1 ether}(
            marketId,
            "encrypted-payload-user-a",
            keccak256("userA-outcome0-0.1eth")
        );

        vm.prank(userB);
        escrow.commitBet{value: 0.05 ether}(
            marketId,
            "encrypted-payload-user-b",
            keccak256("userB-outcome1-0.05eth")
        );
    }

    function _buildBatchData() internal pure returns (
        uint256[] memory newShares,
        uint256[] memory newPrices,
        BanhMiCastMarket.UserAllocation[] memory allocations
    ) {
        allocations = new BanhMiCastMarket.UserAllocation[](2);
        allocations[0] = BanhMiCastMarket.UserAllocation({
            user: address(0xA1),
            sharesMinted: 150,
            outcomeIndex: 0
        });
        allocations[1] = BanhMiCastMarket.UserAllocation({
            user: address(0xB2),
            sharesMinted: 80,
            outcomeIndex: 1
        });

        newShares = new uint256[](2);
        newShares[0] = 150;
        newShares[1] = 80;

        newPrices = new uint256[](2);
        newPrices[0] = 524_000; // ~52.4% (was 500_000)
        newPrices[1] = 476_000; // ~47.6% (was 500_000)
    }

    // =========================================================================
    // Full lifecycle: create → commit → batch → resolve → claim
    // =========================================================================

    function test_fullLifecycle_createAndCommit() public {
        uint256 marketId = _createMarketAndCommitBets();

        assertTrue(marketContract.isActive(marketId));
        assertEq(marketContract.vaultBalance(marketId), 10 ether);
    }

    function test_fullLifecycle_batchResolution() public {
        uint256 marketId = _createMarketAndCommitBets();

        (uint256[] memory newShares, uint256[] memory newPrices,
         BanhMiCastMarket.UserAllocation[] memory allocations) = _buildBatchData();

        bytes memory sig = _signBatchId(1);

        marketContract.resolveBatchWithCre(
            marketId, 1, newShares, newPrices, allocations, sig
        );

        // Verify batch state
        assertEq(marketContract.lastBatchId(marketId), 1);
        assertEq(marketContract.getSharesForOutcome(marketId, 0), 150);
        assertEq(marketContract.getSharesForOutcome(marketId, 1), 80);
        assertEq(marketContract.getCurrentPrice(marketId, 0), 524_000);
        assertEq(marketContract.getCurrentPrice(marketId, 1), 476_000);
    }

    function test_fullLifecycle_positionsCreated() public {
        uint256 marketId = _createMarketAndCommitBets();

        (uint256[] memory newShares, uint256[] memory newPrices,
         BanhMiCastMarket.UserAllocation[] memory allocations) = _buildBatchData();

        marketContract.resolveBatchWithCre(
            marketId, 1, newShares, newPrices, allocations, _signBatchId(1)
        );

        // Verify UserPosition for userA (positionId = 1)
        (address posOwner, uint256 posMkt, uint256 posOutcome, uint256 posShares, bool exists) =
            marketContract.getPosition(1);
        assertEq(posOwner, userA);
        assertEq(posMkt, marketId);
        assertEq(posOutcome, 0);
        assertEq(posShares, 150);
        assertTrue(exists);
    }

    function test_fullLifecycle_resolveAndClaim() public {
        uint256 marketId = _createMarketAndCommitBets();

        (uint256[] memory newShares, uint256[] memory newPrices,
         BanhMiCastMarket.UserAllocation[] memory allocations) = _buildBatchData();

        marketContract.resolveBatchWithCre(
            marketId, 1, newShares, newPrices, allocations, _signBatchId(1)
        );

        // Resolve market — outcome 0 wins
        vm.prank(admin);
        marketContract.resolveMarket(marketId, 0);

        assertFalse(marketContract.isActive(marketId));
        assertEq(marketContract.winningOutcome(marketId), 0);

        // USER_A claims payout (winning position)
        uint256 balBefore = userA.balance;
        vm.prank(userA);
        marketContract.claimPayout(1);

        assertTrue(userA.balance > balBefore);

        // Position should be deleted
        (, , , , bool existsAfter) = marketContract.getPosition(1);
        assertFalse(existsAfter);
    }

    function test_fullLifecycle_loserCannotClaim() public {
        uint256 marketId = _createMarketAndCommitBets();

        (uint256[] memory newShares, uint256[] memory newPrices,
         BanhMiCastMarket.UserAllocation[] memory allocations) = _buildBatchData();

        marketContract.resolveBatchWithCre(
            marketId, 1, newShares, newPrices, allocations, _signBatchId(1)
        );

        vm.prank(admin);
        marketContract.resolveMarket(marketId, 0);

        // USER_B tries to claim (wrong outcome) → revert
        vm.prank(userB);
        vm.expectRevert(WrongOutcome.selector);
        marketContract.claimPayout(2);
    }

    // =========================================================================
    // Test: resolveBatchWithCre — sequence guard (replay protection)
    // =========================================================================

    function test_resolveBatch_revert_replayProtection() public {
        vm.prank(admin);
        marketContract.createMarket{value: 1 ether}("cid", 2, 10_000);

        BanhMiCastMarket.UserAllocation[] memory allocations =
            new BanhMiCastMarket.UserAllocation[](0);

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 0;
        newShares[1] = 0;

        uint256[] memory newPrices = new uint256[](2);
        newPrices[0] = 500_000;
        newPrices[1] = 500_000;

        vm.expectRevert(OutOfSequence.selector);
        marketContract.resolveBatchWithCre(
            1, 99, newShares, newPrices, allocations, _signBatchId(99)
        );
    }

    // =========================================================================
    // Test: resolveBatchWithCre — batch size mismatch guard
    // =========================================================================

    function test_resolveBatch_revert_shapeMismatch() public {
        vm.prank(admin);
        marketContract.createMarket{value: 1 ether}("cid", 2, 10_000);

        BanhMiCastMarket.UserAllocation[] memory allocations =
            new BanhMiCastMarket.UserAllocation[](0);

        uint256[] memory newShares = new uint256[](3); // 3 != 2
        uint256[] memory newPrices = new uint256[](2);
        newPrices[0] = 500_000;
        newPrices[1] = 500_000;

        vm.expectRevert(BatchSizeMismatch.selector);
        marketContract.resolveBatchWithCre(
            1, 1, newShares, newPrices, allocations, _signBatchId(1)
        );
    }

    // =========================================================================
    // Test: resolveBatchWithCre — slippage guard
    // =========================================================================

    function test_resolveBatch_revert_slippageExceeded() public {
        vm.prank(admin);
        marketContract.createMarket{value: 1 ether}("cid", 2, 10_000);

        BanhMiCastMarket.UserAllocation[] memory allocations =
            new BanhMiCastMarket.UserAllocation[](0);

        uint256[] memory newShares = new uint256[](2);

        // Price change of >5%: 500_000 → 600_000 (20% change)
        uint256[] memory newPrices = new uint256[](2);
        newPrices[0] = 600_000;
        newPrices[1] = 400_000;

        vm.expectRevert(SlippageExceeded.selector);
        marketContract.resolveBatchWithCre(
            1, 1, newShares, newPrices, allocations, _signBatchId(1)
        );
    }

    // =========================================================================
    // Test: resolveBatchWithCre — invalid signature
    // =========================================================================

    function test_resolveBatch_revert_invalidSignature() public {
        vm.prank(admin);
        marketContract.createMarket{value: 1 ether}("cid", 2, 10_000);

        BanhMiCastMarket.UserAllocation[] memory allocations =
            new BanhMiCastMarket.UserAllocation[](0);

        uint256[] memory newShares = new uint256[](2);

        uint256[] memory newPrices = new uint256[](2);
        newPrices[0] = 500_000;
        newPrices[1] = 500_000;

        // Sign with WRONG key
        uint256 wrongKey = 0xDEAD;
        bytes32 msgHash = keccak256(abi.encodePacked(uint256(1)));
        bytes32 ethHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, ethHash);
        bytes memory badSig = abi.encodePacked(r, s, v);

        vm.expectRevert(InvalidProof.selector);
        marketContract.resolveBatchWithCre(
            1, 1, newShares, newPrices, allocations, badSig
        );
    }

    // =========================================================================
    // Test: Verifier key rotation
    // =========================================================================

    function test_verifier_keyRotation() public {
        address newSigner = address(0x999);

        vm.prank(admin);
        verifier.setDonSigner(newSigner);

        assertEq(verifier.donSigner(), newSigner);
    }
}
