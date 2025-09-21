// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
  FantasyPacksNFT (no baseURI in constructor)
  - Starts with empty URI ("")
  - Owner can set URI later via setURI
  - Logic contract (or owner) can mint
*/

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/access/Ownable.sol";

contract FantasyPacksNFT is ERC1155, Ownable {
    address public packLogic;

    event PackLogicUpdated(address indexed newLogic);
    event BaseURIUpdated(string newURI);

    modifier onlyPackLogic() {
        require(msg.sender == packLogic || msg.sender == owner(), "Not authorized");
        _;
    }

    // No baseURI arg; starts empty
    constructor() ERC1155("") Ownable(msg.sender) {}

    function setPackLogic(address _logic) external onlyOwner {
        require(_logic != address(0), "Invalid address");
        packLogic = _logic;
        emit PackLogicUpdated(_logic);
    }

    function mintTo(address to, uint256 id, uint256 amount, bytes memory data) external onlyPackLogic {
        _mint(to, id, amount, data);
    }

    // Set later when you actually host metadata
    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
        emit BaseURIUpdated(newuri);
    }
}
