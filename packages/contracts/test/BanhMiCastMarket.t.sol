// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/BanhMiCastVerifier.sol";
import "../src/BanhMiCastMarket.sol";

/// @title BanhMiCastMarket Tests
/// @notice Mirrors the Sui Move `market_tests.move` test suite.
contract BanhMiCastMarketTest is Test {
    BanhMiCastVerifier verifier;
    BanhMiCastMarket market;

    address admin = address(0xAD);
    address userA = address(0xA1);

    // DON signer keypair (Foundry cheatcode-friendly)
    uint256 constant DON_PRIVATE_KEY = 0xBEEF;
    address donSigner;

    function setUp() public {
        donSigner = vm.addr(DON_PRIVATE_KEY);

        vm.startPrank(admin);
        verifier = new BanhMiCastVerifier(donSigner);
        market = new BanhMiCastMarket(address(verifier));
        vm.stopPrank();

        // Fund test accounts
        vm.deal(admin, 100 ether);
        vm.deal(userA, 10 ether);
    }

    // =========================================================================
    // Helper: create a 2-outcome market with 1 ETH initial liquidity
    // =========================================================================

    function _createDefaultMarket() internal returns (uint256 marketId) {
        vm.prank(admin);
        market.createMarket{value: 1 ether}("test_market_cid", 2, 10_000);
        return 1; // first market ID
    }

    // =========================================================================
    // Test: createMarket — success
    // =========================================================================

    function test_createMarket_success() public {
        uint256 marketId = _createDefaultMarket();

        assertTrue(market.isActive(marketId));
        assertEq(market.outcomesCount(marketId), 2);
        assertEq(market.liquidityB(marketId), 10_000);
        assertEq(market.lastBatchId(marketId), 0);
        assertEq(market.vaultBalance(marketId), 1 ether);

        // Uniform prices: 1_000_000 / 2 = 500_000 each
        assertEq(market.getCurrentPrice(marketId, 0), 500_000);
        assertEq(market.getCurrentPrice(marketId, 1), 500_000);

        // Shares start at 0
        assertEq(market.getSharesForOutcome(marketId, 0), 0);
        assertEq(market.getSharesForOutcome(marketId, 1), 0);
    }

    // =========================================================================
    // Test: createMarket — revert on invalid outcomes count (< 2)
    // =========================================================================

    function test_createMarket_revert_invalidOutcomes() public {
        vm.prank(admin);
        vm.expectRevert(InvalidOutcomesCount.selector);
        market.createMarket{value: 1 ether}("bad_market", 1, 10_000);
    }

    // =========================================================================
    // Test: createMarket — revert on zero liquidity_b
    // =========================================================================

    function test_createMarket_revert_zeroLiquidity() public {
        vm.prank(admin);
        vm.expectRevert(InsufficientLiquidity.selector);
        market.createMarket{value: 1 ether}("zero_b", 2, 0);
    }

    // =========================================================================
    // Test: createMarket — revert if non-owner
    // =========================================================================

    function test_createMarket_revert_notOwner() public {
        vm.prank(userA);
        vm.expectRevert(NotAuthorized.selector);
        market.createMarket{value: 1 ether}("not_owner", 2, 10_000);
    }

    // =========================================================================
    // Test: resolveMarket — success
    // =========================================================================

    function test_resolveMarket_success() public {
        uint256 marketId = _createDefaultMarket();

        vm.prank(admin);
        market.resolveMarket(marketId, 0);

        assertFalse(market.isActive(marketId));
        assertEq(market.winningOutcome(marketId), 0);
    }

    // =========================================================================
    // Test: resolveMarket — revert if already resolved
    // =========================================================================

    function test_resolveMarket_revert_doubleResolve() public {
        uint256 marketId = _createDefaultMarket();

        vm.startPrank(admin);
        market.resolveMarket(marketId, 0);

        vm.expectRevert(MarketAlreadyResolved.selector);
        market.resolveMarket(marketId, 1);
        vm.stopPrank();
    }

    // =========================================================================
    // Test: resolveMarket — correct state after resolution
    // =========================================================================

    function test_resolveMarket_setsWinner() public {
        uint256 marketId = _createDefaultMarket();

        vm.prank(admin);
        market.resolveMarket(marketId, 1); // outcome 1 wins

        assertFalse(market.isActive(marketId));
        assertEq(market.winningOutcome(marketId), 1);
    }

    // =========================================================================
    // Test: resolveMarket — revert on invalid outcome index
    // =========================================================================

    function test_resolveMarket_revert_wrongOutcome() public {
        uint256 marketId = _createDefaultMarket();

        vm.prank(admin);
        vm.expectRevert(WrongOutcome.selector);
        market.resolveMarket(marketId, 5); // outcome 5 doesn't exist in 2-outcome market
    }
}
