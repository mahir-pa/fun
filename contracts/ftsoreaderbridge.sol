// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * FtsoUsdReaderBridge
 * - Normalizes different FTSO reader interfaces to a single call:
 *     getPrice(bytes32 symbol) -> (price, decimals)
 * - Supports:
 *     A) String API: getCurrentPriceWithDecimals(string)
 *     B) Bytes32 API: getPrice(bytes32)
 * - Ships with a manual (owner-only) override switch for emergencies.
 *
 * Usage with your FantasyPacksLogic:
 *   1) Deploy this.
 *   2) call setTarget(<ftsoReader>, true/false, "FLR/USD")
 *   3) In FantasyPacksLogic.setFtso(<this contract address>)
 *   4) Set USD pegs: setUSDPrices(1e18, 5e18, 10e18)
 */

interface IFtsoStringAPI {
    function getCurrentPriceWithDecimals(string calldata symbol)
        external
        view
        returns (uint256 price, uint8 decimals);
}

interface IFtsoBytes32API {
    function getPrice(bytes32 symbol)
        external
        view
        returns (uint256 price, uint8 decimals);
}

contract FtsoUsdReaderBridge {
    address public owner;

    // If true, call string API; if false, call bytes32 API.
    bool    public useStringAPI;
    address public target;              // address of the underlying FTSO reader

    // The symbol name expected by the underlying reader for FLR/USD.
    // Example: "FLR/USD"
    string  public flrUsdSymbolString;
    // For bytes32 API readers. Often keccak256("FLR/USD") or a bespoke code.
    bytes32 public flrUsdSymbolBytes32;

    // Manual override (emergency): when enabled, getPrice returns this value.
    bool    public manualOverrideEnabled;
    uint256 public manualPrice;   // USD per FLR
    uint8   public manualDecimals;

    // Canonical symbol your logic contract uses
    bytes32 public constant SYM_FLRUSD = keccak256("FLR/USD");

    event TargetSet(address indexed target, bool useStringAPI, string symString, bytes32 symBytes32);
    event ManualOverrideSet(bool enabled, uint256 price, uint8 decimals);
    event OwnerChanged(address indexed prev, address indexed next);

    modifier onlyOwner() { require(msg.sender == owner, "not owner"); _; }

    constructor() {
        owner = msg.sender;
        // sensible defaults; you will set these correctly via setTarget
        useStringAPI = true;
        flrUsdSymbolString = "FLR/USD";
        flrUsdSymbolBytes32 = keccak256(bytes("FLR/USD"));
    }

    function setOwner(address next) external onlyOwner {
        require(next != address(0), "zero");
        emit OwnerChanged(owner, next);
        owner = next;
    }

    /**
     * @param reader Address of the FTSO reader on Coston2.
     * @param _useStringAPI true if it exposes getCurrentPriceWithDecimals(string)
     * @param symbolString The exact symbol that reader expects for FLR/USD, eg "FLR/USD"
     * @param symbolBytes32 The bytes32 symbol if the reader uses bytes32 keys.
     */
    function setTarget(
        address reader,
        bool _useStringAPI,
        string calldata symbolString,
        bytes32 symbolBytes32
    ) external onlyOwner {
        require(reader != address(0), "zero reader");
        target = reader;
        useStringAPI = _useStringAPI;
        flrUsdSymbolString = symbolString;
        flrUsdSymbolBytes32 = symbolBytes32;
        emit TargetSet(reader, _useStringAPI, symbolString, symbolBytes32);
    }

    /**
     * Manual override in case the oracle is unavailable during a demo.
     * e.g. enable=true, price=250000000000000000 (0.25), decimals=18
     */
    function setManualOverride(
        bool enable,
        uint256 price,
        uint8 decimals
    ) external onlyOwner {
        manualOverrideEnabled = enable;
        manualPrice = price;
        manualDecimals = decimals;
        emit ManualOverrideSet(enable, price, decimals);
    }

    /**
     * Normalized getter your logic calls.
     * Right now we only map SYM_FLRUSD; if you add FXRP later, extend this to map it.
     */
    function getPrice(bytes32 symbol)
        external
        view
        returns (uint256 price, uint8 decimals)
    {
        require(symbol == SYM_FLRUSD, "unsupported symbol");

        if (manualOverrideEnabled) {
            return (manualPrice, manualDecimals);
        }

        address r = target;
        require(r != address(0), "reader not set");

        if (useStringAPI) {
            return IFtsoStringAPI(r).getCurrentPriceWithDecimals(flrUsdSymbolString);
        } else {
            return IFtsoBytes32API(r).getPrice(flrUsdSymbolBytes32);
        }
    }
}
