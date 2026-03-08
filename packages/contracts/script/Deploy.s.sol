// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/BanhMiCastVerifier.sol";
import "../src/BanhMiCastMarket.sol";
import "../src/BanhMiCastEscrow.sol";

/// @title BanhMiCast — Sepolia Deployment Script
/// @notice Deploys: Verifier → Market → Escrow
/// @dev Usage:
///   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL \
///     --private-key $CRE_ETH_PRIVATE_KEY --broadcast
contract DeployBanhMiCast is Script {
    function run() external {
        // The DON signer address — replace with actual DON address for production.
        address donSigner = vm.envOr("DON_SIGNER", address(0x1));

        vm.startBroadcast();

        // 1. Deploy Verifier
        BanhMiCastVerifier verifier = new BanhMiCastVerifier(donSigner);
        console.log("BanhMiCastVerifier deployed at:", address(verifier));

        // 2. Deploy Market (references Verifier)
        BanhMiCastMarket market = new BanhMiCastMarket(address(verifier));
        console.log("BanhMiCastMarket deployed at:", address(market));

        // 3. Deploy Escrow (references Market)
        BanhMiCastEscrow escrowContract = new BanhMiCastEscrow(address(market));
        console.log("BanhMiCastEscrow deployed at:", address(escrowContract));

        vm.stopBroadcast();
    }
}
