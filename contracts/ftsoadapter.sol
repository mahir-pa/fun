// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Periphery interfaces (Coston2)
import {ContractRegistry} from "@flarenetwork/flare-periphery-contracts/coston2/ContractRegistry.sol";
import {TestFtsoV2Interface} from "@flarenetwork/flare-periphery-contracts/coston2/TestFtsoV2Interface.sol";
// If you want prod-payable version later, switch to FtsoV2Interface and ContractRegistry.getFtsoV2()

/**
 * FtsoV2ReaderAdapter (Coston2)
 * - Normalizes FTSOv2 to: getPrice(bytes32) -> (price, decimals)
 * - Reads FLR/USD via bytes21 feed id 0x01464c522f55534400000000000000000000000000
 *   per Flare docs. (Block-latency feed IDs) 
 */
contract FtsoV2ReaderAdapter {
    // keccak256("FLR/USD")
    bytes32 public constant SYM_FLRUSD =
        0x188f9870080c5fe7cf6af18c257abe5d37e0da28dd459e3adee9acf24fb95e1c;

    // bytes21("FLR/USD") with 0x01 prefix then ASCII then zero padding (from docs)
    bytes21 public constant FEED_FLR_USD =
        0x01464c522f55534400000000000000000000000000;

    // Returns USD per FLR (value, decimals)
    function getPrice(bytes32 symbol) external view returns (uint256 price, uint8 decimals) {
        require(symbol == SYM_FLRUSD, "unsupported symbol");
        // Test interface is view-only on Coston2 guides; fine for reading price
        TestFtsoV2Interface ftsoV2 = ContractRegistry.getTestFtsoV2();
        (uint256 v, int8 dec, /*ts*/) = ftsoV2.getFeedById(FEED_FLR_USD);
        require(dec >= 0, "bad decimals");
        return (v, uint8(uint8(dec)));
    }
}
