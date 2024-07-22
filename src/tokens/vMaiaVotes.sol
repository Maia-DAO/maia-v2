// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC20MultiVotes} from "@ERC20/ERC20MultiVotes.sol";

import {IvMaiaUnderlying} from "../interfaces/IvMaiaUnderlying.sol";

/**
 * @title vMaiaVotes: Have power over Maia's governance
 * @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Represents the underlying governance power of a VoteMaia token.
 */
contract vMaiaVotes is ERC20MultiVotes, IvMaiaUnderlying {
    /// @inheritdoc IvMaiaUnderlying
    address public immutable override vMaia;

    constructor(address _owner) ERC20("VoteMaia Votes", "vMAIA-V", 18) {
        _initializeOwner(_owner);
        vMaia = msg.sender;
    }

    /// @inheritdoc IvMaiaUnderlying
    function mint(address to, uint256 amount) external override onlyvMaia {
        _mint(to, amount);
    }

    /**
     * @notice Burns Burnt Hermes gauge tokens
     * @param from account to burn tokens from
     * @param amount amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyvMaia {
        _burn(from, amount);
    }

    modifier onlyvMaia() {
        if (msg.sender != vMaia) revert NotvMaia();
        _;
    }
}
