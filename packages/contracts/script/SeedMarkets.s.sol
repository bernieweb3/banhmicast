// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BanhMiCastMarket} from "../src/BanhMiCastMarket.sol";

/// @title SeedMarkets — Creates demo markets on deployed BanhMiCastMarket.
/// @notice Run with:
///     forge script script/SeedMarkets.s.sol:SeedMarkets \
///         --rpc-url https://1rpc.io/sepolia \
///         --private-key $CRE_ETH_PRIVATE_KEY --broadcast
contract SeedMarkets is Script {
    function run() external {
        // Market contract deployed on Sepolia
        address marketAddr = 0xD782a3f67dc7d870aB8bb368FC429dC0BcBd4935;
        BanhMiCastMarket market = BanhMiCastMarket(payable(marketAddr));

        vm.startBroadcast();

        // Market 1: ETH/BTC Ratio
        market.createMarket{value: 0.01 ether}(
            "ETH/BTC Ratio > 0.05 by June 2026?",
            2,      // outcomes: Yes, No
            1000    // liquidityB
        );
        console.log("Market 1 created");

        // Market 2: Ethereum L2 TVL
        market.createMarket{value: 0.01 ether}(
            "Ethereum L2 TVL > $100B by Q3 2026?",
            2,
            2000
        );
        console.log("Market 2 created");

        // Market 3: Bitcoin ATH
        market.createMarket{value: 0.01 ether}(
            "Bitcoin All-Time High Before July 2026?",
            2,
            5000
        );
        console.log("Market 3 created");

        // Market 4: Fed Rate (3 outcomes)
        market.createMarket{value: 0.01 ether}(
            "Fed Cuts Rate in June 2026?",
            3,      // outcomes: Cut, Hold, Hike
            3000
        );
        console.log("Market 4 created");

        // Market 5: Chainlink CCIP Volume
        market.createMarket{value: 0.01 ether}(
            "Chainlink CCIP Cross-Chain Volume > $50B?",
            2,
            800
        );
        console.log("Market 5 created");

        // Market 6: Vietnam Football
        market.createMarket{value: 0.01 ether}(
            "Vietnam National Football - SEA Games Gold?",
            2,
            1500
        );
        console.log("Market 6 created");

        vm.stopBroadcast();
    }
}
