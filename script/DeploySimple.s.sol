// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {console2} from "forge-std/console2.sol";
import {FallbackPriceFeed} from "src/FallbackPriceFeed.sol";

// For reference, these Avalanche Mainnet addresses:
address constant WAVAX_ADDRESS = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
address constant SAVAX_ADDRESS = 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE;
address constant BTCb_ADDRESS  = 0x152b9d0FdC40C096757F570A51E494bd4b943E50;

// Oracles
address constant WAVAX_ORACLE_PRIMARY   = 0x0A77230d17318075983913bC2145DB16C7366156;
uint256 constant WAVAX_PRIMARY_STALENESS   = 48 hours;
address constant WAVAX_ORACLE_SECONDARY = 0x9450A29eF091B625e976cE66f2A5818e20791999;
uint256 constant WAVAX_SECONDARY_STALENESS = 24 hours;

address constant SAVAX_ORACLE_PRIMARY   = 0x2854Ca10a54800e15A2a25cFa52567166434Ff0a;
uint256 constant SAVAX_PRIMARY_STALENESS   = 48 hours;
address constant SAVAX_ORACLE_SECONDARY = 0x3d7f3268c0F4bc97C0C89e3e3b19b2779527c0E2;
uint256 constant SAVAX_SECONDARY_STALENESS = 24 hours;

address constant BTCb_ORACLE_PRIMARY   = 0x2779D32d5166BAaa2B2b658333bA7e6Ec0C65743;
uint256 constant BTCb_PRIMARY_STALENESS   = 48 hours;
address constant BTCb_ORACLE_SECONDARY = 0x6d281fB4200074b48abB0C9e1b9E86613007D7f4;
uint256 constant BTCb_SECONDARY_STALENESS = 24 hours;

contract DeploySimple is Script, StdCheats {
    using Strings for uint256;

    bytes32 public SALT;
    address public deployer;
    FallbackPriceFeed[] public priceFeeds;

    function run() external {
        // 1. Resolve environment variables for SALT and DEPLOYER
        string memory saltStr = vm.envOr("SALT", block.timestamp.toString());
        SALT = keccak256(bytes(saltStr));

        // If your DEPLOYER is a private key
        uint256 deployerPk = vm.envUint("DEPLOYER");
        deployer = vm.addr(deployerPk);

        console2.log("Deployer:", deployer);

        // Split the "Salt" message into two calls:
        console2.log("Salt    :", saltStr);
        console2.log(string.concat("( => ", Strings.toHexString(uint256(SALT), 32), ")"));

        vm.startBroadcast(deployerPk);

        // Initialize arrays
        priceFeeds = new FallbackPriceFeed[](3);

        // Deploy fallback price feeds
        priceFeeds[0] = new FallbackPriceFeed(
            WAVAX_ORACLE_PRIMARY,   WAVAX_PRIMARY_STALENESS,
            WAVAX_ORACLE_SECONDARY, WAVAX_SECONDARY_STALENESS,
            deployer
        );
        console2.log("WAVAX fallback feed:", address(priceFeeds[0]));

        priceFeeds[1] = new FallbackPriceFeed(
            SAVAX_ORACLE_PRIMARY,   SAVAX_PRIMARY_STALENESS,
            SAVAX_ORACLE_SECONDARY, SAVAX_SECONDARY_STALENESS,
            deployer
        );
        console2.log("sAVAX fallback feed:", address(priceFeeds[1]));

        priceFeeds[2] = new FallbackPriceFeed(
            BTCb_ORACLE_PRIMARY,   BTCb_PRIMARY_STALENESS,
            BTCb_ORACLE_SECONDARY, BTCb_SECONDARY_STALENESS,
            deployer
        );
        console2.log("BTCb fallback feed :", address(priceFeeds[2]));

        vm.stopBroadcast();
    }
}

