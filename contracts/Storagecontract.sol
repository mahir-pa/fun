// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
  Fantasy Packs Storage Contract
  Handles player data storage and management
  Deployed on Flare Coston2 Testnet
*/

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/access/Ownable.sol";

contract FantasyPacksStorage is Ownable {
    enum Tier { Basic, Epic, Legendary }
    
    struct Player {
        string name;
        uint8 tier;
        bool exists;
    }
    
    mapping(uint256 => Player) public players;
    uint256[] public basicPool;
    uint256[] public epicPool;
    uint256[] public legendPool;
    
    // Access control for the main contract
    address public mainContract;
    
    event PlayersAdded(Tier tier, uint256 count);
    event MainContractUpdated(address indexed newMainContract);
    
    modifier onlyMainContract() {
        require(msg.sender == mainContract || msg.sender == owner(), "Not authorized");
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    // Set the main contract address that can read data
    function setMainContract(address _mainContract) external onlyOwner {
        require(_mainContract != address(0), "Invalid address");
        mainContract = _mainContract;
        emit MainContractUpdated(_mainContract);
    }
    
    // Add players to the contract
    function addPlayers(
        uint256[] calldata ids, 
        string[] calldata names, 
        uint8 tier
    ) external onlyOwner {
        require(ids.length == names.length, "Length mismatch");
        require(tier <= 2, "Invalid tier");
        
        for (uint256 i = 0; i < ids.length; i++) {
            _addPlayer(ids[i], names[i], tier);
        }
        
        emit PlayersAdded(Tier(tier), ids.length);
    }
    
    // Add multiple players in batches (for gas optimization)
    function addPlayersBatch(
        uint256[] calldata ids,
        string[] calldata names,
        uint8[] calldata tiers
    ) external onlyOwner {
        require(ids.length == names.length && ids.length == tiers.length, "Length mismatch");
        
        for (uint256 i = 0; i < ids.length; i++) {
            require(tiers[i] <= 2, "Invalid tier");
            _addPlayer(ids[i], names[i], tiers[i]);
        }
    }
    
    // Internal function to add a player
    function _addPlayer(uint256 id, string memory name, uint8 tier) internal {
        require(!players[id].exists, "Player exists");
        players[id] = Player(name, tier, true);
        
        if (tier == 0) {
            basicPool.push(id);
        } else if (tier == 1) {
            epicPool.push(id);
        } else {
            legendPool.push(id);
        }
    }
    
    // View functions for the main contract
    function getPlayer(uint256 id) external view returns (string memory name, uint8 tier, bool exists) {
        Player memory p = players[id];
        return (p.name, p.tier, p.exists);
    }
    
    function getPoolSizes() external view returns (uint256 basic, uint256 epic, uint256 legendary) {
        return (basicPool.length, epicPool.length, legendPool.length);
    }
    
    function getBasicPoolLength() external view returns (uint256) {
        return basicPool.length;
    }
    
    function getEpicPoolLength() external view returns (uint256) {
        return epicPool.length;
    }
    
    function getLegendPoolLength() external view returns (uint256) {
        return legendPool.length;
    }
    
    function getBasicPoolId(uint256 index) external view onlyMainContract returns (uint256) {
        require(index < basicPool.length, "Index out of bounds");
        return basicPool[index];
    }
    
    function getEpicPoolId(uint256 index) external view onlyMainContract returns (uint256) {
        require(index < epicPool.length, "Index out of bounds");
        return epicPool[index];
    }
    
    function getLegendPoolId(uint256 index) external view onlyMainContract returns (uint256) {
        require(index < legendPool.length, "Index out of bounds");
        return legendPool[index];
    }
    
    // Clear pools (use with caution)
    function clearPools() external onlyOwner {
        delete basicPool;
        delete epicPool;
        delete legendPool;
    }
    
    // Remove a specific player (emergency function)
    function removePlayer(uint256 id) external onlyOwner {
        require(players[id].exists, "Player doesn't exist");
        
        uint8 tier = players[id].tier;
        delete players[id];
        
        // Note: This doesn't remove from pools to save gas
        // Consider rebuilding pools if needed
    }
}