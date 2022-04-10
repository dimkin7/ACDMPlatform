// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DimaERC20 is ERC20, AccessControl {
    bytes32 public constant PLATFORM_ROLE = keccak256("PLATFORM_ROLE");

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addPlatform(address platform) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(PLATFORM_ROLE, platform);
    }

    function removePlatform(address platform)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(PLATFORM_ROLE, platform);
    }

    function mint(address account, uint256 amount)
        public
        onlyRole(PLATFORM_ROLE)
    {
        _mint(account, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(PLATFORM_ROLE) {
        _burn(from, amount);
    }
}
