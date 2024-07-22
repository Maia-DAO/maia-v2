// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title VoteMaia Underlying
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Represents the underlying position of the VoteMaia token.
 */
interface IvMaiaUnderlying {
    /// @notice thrown when minter is not VoteMaia contract.
    error NotvMaia();

    /**
     * @notice
     */
    function vMaia() external view returns (address);

    /**
     * @notice Mints new VoteMaia underlying tokens to a specific account.
     * @param to account to transfer VoteMaia underlying tokens to
     * @param amount amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external;
}
