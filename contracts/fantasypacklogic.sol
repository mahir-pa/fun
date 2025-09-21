// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
  FantasyPacksLogic (No FTSO)
  - Native FLR pricing in raw wei (default 1/2/3 FLR).
  - ERC20 payments for FAssets (FXRP, FBTC, FETH, etc.) via setTokenPrices.
  - Odds/selection/mint unchanged. Simple PRNG for test use only.
*/

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/utils/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/utils/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC20/IERC20.sol";

interface IFantasyPacksNFT {
    function mintTo(address to, uint256 id, uint256 amount, bytes calldata data) external;
}

interface IFantasyPacksStorage {
    enum Tier { Basic, Epic, Legendary }
    function setMainContract(address _mainContract) external;
    function getPoolSizes() external view returns (uint256 basic, uint256 epic, uint256 legendary);
    function getBasicPoolId(uint256 index) external view returns (uint256);
    function getEpicPoolId(uint256 index) external view returns (uint256);
    function getLegendPoolId(uint256 index) external view returns (uint256);
    function getPlayer(uint256 id) external view returns (string memory name, uint8 tier, bool exists);
}

contract FantasyPacksLogic is Ownable, Pausable, ReentrancyGuard {
    enum Pack { Basic, Epic, Legendary }

    IFantasyPacksNFT public nft;
    IFantasyPacksStorage public store;

    // -------- Native FLR prices (wei) --------
    mapping(Pack => uint256) public packPrice; // e.g. 1 ether, 2 ether, 3 ether

    // -------- ERC20 token pricing --------
    struct TokenCfg {
        bool allowed;
        uint256 basic;     // raw token units
        uint256 epic;      // raw token units
        uint256 legendary; // raw token units
    }
    mapping(address => TokenCfg) public tokenCfg;

    // -------- Odds --------
    struct Odds {
        uint16 toBasic;
        uint16 toEpic;
        uint16 toLegendary;
    }
    mapping(Pack => Odds) public odds;

    uint256 private nonce;

    // -------- Events --------
    event OpenedPack(address indexed user, uint8 packType, uint256 playerId, uint8 rolledTier);
    event PricesUpdated(uint256 basicWei, uint256 epicWei, uint256 legendaryWei);
    event TokenAllowed(address indexed token, bool allowed);
    event TokenPricesUpdated(address indexed token, uint256 basic, uint256 epic, uint256 legendary);
    event NFTSet(address indexed nft);
    event StorageSet(address indexed storageContract);
    event Withdraw(address indexed to, uint256 amount);
    event WithdrawToken(address indexed token, address indexed to, uint256 amount);

    constructor(address storageContract, address nftContract) Ownable(msg.sender) {
        require(storageContract != address(0) && nftContract != address(0), "Zero addr");
        store = IFantasyPacksStorage(storageContract);
        nft   = IFantasyPacksNFT(nftContract);

        // Native FLR default prices
        packPrice[Pack.Basic]     = 1 ether;
        packPrice[Pack.Epic]      = 2 ether;
        packPrice[Pack.Legendary] = 3 ether;

        // Default odds (sum 10_000)
        odds[Pack.Basic]     = Odds({toBasic: 9400, toEpic: 550,  toLegendary: 50});
        odds[Pack.Epic]      = Odds({toBasic: 1000, toEpic: 8200, toLegendary: 800});
        odds[Pack.Legendary] = Odds({toBasic: 200,  toEpic: 1800, toLegendary: 8000});

        emit StorageSet(storageContract);
        emit NFTSet(nftContract);
        emit PricesUpdated(packPrice[Pack.Basic], packPrice[Pack.Epic], packPrice[Pack.Legendary]);
    }

    // ---------------- Admin ----------------

    function setPrices(uint256 basicWei, uint256 epicWei, uint256 legendaryWei) external onlyOwner {
        packPrice[Pack.Basic]     = basicWei;
        packPrice[Pack.Epic]      = epicWei;
        packPrice[Pack.Legendary] = legendaryWei;
        emit PricesUpdated(basicWei, epicWei, legendaryWei);
    }

    function setOdds(Pack pack, uint16 toBasic, uint16 toEpic, uint16 toLegendary) external onlyOwner {
        require(uint256(toBasic) + uint256(toEpic) + uint256(toLegendary) == 10_000, "Odds sum != 100%");
        odds[pack] = Odds({toBasic: toBasic, toEpic: toEpic, toLegendary: toLegendary});
    }

    function setNFT(address nftContract) external onlyOwner {
        require(nftContract != address(0), "Zero addr");
        nft = IFantasyPacksNFT(nftContract);
        emit NFTSet(nftContract);
    }

    function setStorage(address storageContract) external onlyOwner {
        require(storageContract != address(0), "Zero addr");
        store = IFantasyPacksStorage(storageContract);
        emit StorageSet(storageContract);
    }

    // ERC20 configuration
    function setTokenAllowed(address token, bool allowed) external onlyOwner {
        tokenCfg[token].allowed = allowed;
        emit TokenAllowed(token, allowed);
    }

    // raw units in token decimals. For FXRP (6 dec) use 1e6, 2e6, 5e6.
    function setTokenPrices(address token, uint256 basic, uint256 epic, uint256 legendary) external onlyOwner {
        TokenCfg storage c = tokenCfg[token];
        require(c.allowed, "Token not allowed");
        c.basic = basic; c.epic = epic; c.legendary = legendary;
        emit TokenPricesUpdated(token, basic, epic, legendary);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function withdraw(address payable to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Zero addr");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Withdraw failed");
        emit Withdraw(to, amount);
    }

    function withdrawToken(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Zero addr");
        require(IERC20(token).transfer(to, amount), "ERC20 transfer failed");
        emit WithdrawToken(token, to, amount);
    }

    // ---------------- User flow ----------------

    // Pay with native FLR at fixed wei price
    function buyAndOpenPack(uint8 packType)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 playerId, uint8 rolledTier)
    {
        require(packType <= uint8(Pack.Legendary), "bad pack");
        uint256 price = packPrice[Pack(packType)];
        require(msg.value == price, "bad value");

        rolledTier = _rollTier(Pack(packType));
        playerId   = _drawPlayerFromTierWithFallback(rolledTier);

        nft.mintTo(msg.sender, playerId, 1, "");
        emit OpenedPack(msg.sender, packType, playerId, rolledTier);
    }

    // Pay with ERC20 token (e.g., FXRP/FBTC/FETH)
    // amount must equal the configured price (raw token units).
    function buyWithToken(address token, uint8 packType, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 playerId, uint8 rolledTier)
    {
        require(packType <= uint8(Pack.Legendary), "bad pack");
        TokenCfg memory c = tokenCfg[token];
        require(c.allowed, "token not allowed");

        uint256 need = packType == uint8(Pack.Basic) ? c.basic :
                       packType == uint8(Pack.Epic) ? c.epic  : c.legendary;
        require(need > 0, "price not set");
        require(amount == need, "bad amount");

        // Pull funds
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        rolledTier = _rollTier(Pack(packType));
        playerId   = _drawPlayerFromTierWithFallback(rolledTier);

        nft.mintTo(msg.sender, playerId, 1, "");
        emit OpenedPack(msg.sender, packType, playerId, rolledTier);
    }

    // ---------------- Views ----------------
    function getPrices() external view returns (uint256 basicWei, uint256 epicWei, uint256 legendaryWei) {
        return (packPrice[Pack.Basic], packPrice[Pack.Epic], packPrice[Pack.Legendary]);
    }

    function isTokenAllowed(address token) external view returns (bool) {
        return tokenCfg[token].allowed;
    }

    function getTokenPrices(address token) external view returns (uint256 basic, uint256 epic, uint256 legendary) {
        TokenCfg memory c = tokenCfg[token];
        return (c.basic, c.epic, c.legendary);
    }

    function getPackOdds(uint8 packType) external view returns (uint16 toBasic, uint16 toEpic, uint16 toLegendary) {
        Odds memory o = odds[Pack(packType)];
        return (o.toBasic, o.toEpic, o.toLegendary);
    }

    // ---------------- Internal RNG & selection ----------------
    function _rollTier(Pack packType) internal returns (uint8) {
        uint256 r = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, nonce++, address(this)))
        ) % 10_000;

        Odds memory o = odds[packType];
        if (r < o.toBasic) return 0;
        if (r < o.toBasic + o.toEpic) return 1;
        return 2;
    }

    function _drawPlayerFromTierWithFallback(uint8 tier) internal view returns (uint256 id) {
        (uint256 lb, uint256 le, uint256 ll) = store.getPoolSizes();

        if (tier == 0 && lb > 0) return _idFromBasic(lb);
        if (tier == 1 && le > 0) return _idFromEpic(le);
        if (tier == 2 && ll > 0) return _idFromLegend(ll);

        if (lb + le + ll == 0) revert("No players in pools");

        if (tier == 0) {
            if (le > 0) return _idFromEpic(le);
            return _idFromLegend(ll);
        } else if (tier == 1) {
            if (lb > 0) return _idFromBasic(lb);
            return _idFromLegend(ll);
        } else {
            if (le > 0) return _idFromEpic(le);
            return _idFromBasic(lb);
        }
    }

    function _randomIndex(uint256 len, bytes32 salt) internal view returns (uint256) {
        require(len > 0, "Empty pool");
        uint256 r = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, address(this), salt)));
        return r % len;
    }

    function _idFromBasic(uint256 len) internal view returns (uint256) {
        uint256 idx = _randomIndex(len, "BASIC");
        return store.getBasicPoolId(idx);
    }

    function _idFromEpic(uint256 len) internal view returns (uint256) {
        uint256 idx = _randomIndex(len, "EPIC");
        return store.getEpicPoolId(idx);
    }

    function _idFromLegend(uint256 len) internal view returns (uint256) {
        uint256 idx = _randomIndex(len, "LEGEND");
        return store.getLegendPoolId(idx);
    }

    // Guard accidental transfers
    receive() external payable { revert("Use buyAndOpenPack"); }
    fallback() external payable { revert("Nope"); }
}
