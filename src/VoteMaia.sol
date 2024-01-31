// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {DateTimeLib} from "./libraries/DateTimeLib.sol";
import {ERC4626PartnerManager, PartnerManagerFactory} from "./tokens/ERC4626PartnerManager.sol";

/**
 * @title VoteMaia: Yield bearing, boosting, voting, and gauge enabled MAIA
 * @author Maia DAO (https://github.com/Maia-DAO)
 * @notice VoteMaia is an ERC-4626 compliant MAIA token which:
 *         distributes BurntHermes utility tokens (Weight, Governance) and Maia Governance
 *         in exchange for staking MAIA.
 *
 *         NOTE: Withdraw is only allowed once per month,
 *               during the 1st Tuesday (UTC+0) of the month that someone withdraws.
 */
contract VoteMaia is ERC4626PartnerManager {
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                            VOTE MAIA STATE
    ///////////////////////////////////////////////////////////////*/

    uint128 private currentMonth;
    uint128 private unstakePeriodEnd;

    /**
     * @notice Initializes the VoteMaia token.
     * @param _factory The factory that keeps the registry for all partner tokens and vaults.
     * @param _bHermesRate The rate at which BurntHermes can be claimed.
     * @param _partnerAsset The asset that will be used to deposit to get VoteMaia.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _bHermes The address of the BurntHermes token.
     * @param _partnerVault The address of the partner vault.
     * @param _owner The owner of the token.
     */
    constructor(
        PartnerManagerFactory _factory,
        uint256 _bHermesRate,
        ERC20 _partnerAsset,
        string memory _name,
        string memory _symbol,
        address _bHermes,
        address _partnerVault,
        address _owner
    ) ERC4626PartnerManager(_factory, _bHermesRate, _partnerAsset, _name, _symbol, _bHermes, _partnerVault, _owner) {
        // Set the current month to the current month.
        currentMonth = DateTimeLib.getMonth(block.timestamp).toUint128();
    }

    /*///////////////////////////////////////////////////////////////
                         UTILITY TOKENS LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @dev Boost can't be forfeit; does not fail.
    function forfeitBoost(uint256 amount) public override {}

    /*///////////////////////////////////////////////////////////////
                         UTILITY MANAGER LOGIC
    ///////////////////////////////////////////////////////////////*/

    function claimOutstanding() public override {
        uint256 balance = balanceOf[msg.sender].mulWad(bHermesRate);
        /// @dev Never overflows since balandeOf >= userClaimed.
        unchecked {
            claimWeight(balance - userClaimedWeight[msg.sender]);
            claimGovernance(balance - userClaimedGovernance[msg.sender]);
            claimPartnerGovernance(balance - userClaimedPartnerGovernance[msg.sender]);
        }
    }

    function forfeitOutstanding() public override {
        forfeitWeight(userClaimedWeight[msg.sender]);
        forfeitGovernance(userClaimedGovernance[msg.sender]);
        forfeitPartnerGovernance(userClaimedPartnerGovernance[msg.sender]);
    }

    /*///////////////////////////////////////////////////////////////
                               MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    /// @dev Boost can't be claimed; does not fail. It is all used by the partner vault.
    function claimBoost(uint256) public override {}

    /*//////////////////////////////////////////////////////////////
                    ER4626 WITHDRAWAL LIMIT LOGIC
    ///////////////////////////////////////////////////////////////*/

    function _checkIfWithdrawalIsAllowed() internal view returns (bool) {
        /// @dev Return true if unstake period has not ended yet.
        if (unstakePeriodEnd >= block.timestamp) return true;

        uint256 _currentMonth = DateTimeLib.getMonth(block.timestamp);
        if (_currentMonth == currentMonth) return false;

        (bool isTuesday,) = DateTimeLib.isTuesday(block.timestamp);
        return isTuesday;
    }

    /// @notice Returns the maximum amount of assets that can be withdrawn by a user.
    /// @dev Assumes that the user has already forfeited all utility tokens.
    function maxWithdraw(address user) public view virtual override returns (uint256) {
        return _checkIfWithdrawalIsAllowed() ? super.maxWithdraw(user) : 0;
    }

    /// @notice Returns the maximum amount of assets that can be redeemed by a user.
    /// @dev Assumes that the user has already forfeited all utility tokens.
    function maxRedeem(address user) public view virtual override returns (uint256) {
        return _checkIfWithdrawalIsAllowed() ? super.maxRedeem(user) : 0;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function that performs the necessary verifications before a user can withdraw from their VoteMaia position.
     *  Checks if we're inside the unstaked period, if so then the user can withdraw.
     * If we're not in the unstake period, then there will be checks to determine if this is the beginning of the month.
     */
    function beforeWithdraw(uint256, uint256) internal override {
        /// @dev Check if unstake period has not ended yet, continue if it is the case.
        if (unstakePeriodEnd >= block.timestamp) return;

        uint128 _currentMonth = DateTimeLib.getMonth(block.timestamp).toUint128();
        if (_currentMonth == currentMonth) revert UnstakePeriodNotLive();

        (bool isTuesday, uint256 _unstakePeriodStart) = DateTimeLib.isTuesday(block.timestamp);
        if (!isTuesday) revert UnstakePeriodNotLive();

        currentMonth = _currentMonth;
        unstakePeriodEnd = (_unstakePeriodStart + 1 days).toUint128();
    }

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @dev Error thrown when trying to withdraw and it is not the first Tuesday of the month.
    error UnstakePeriodNotLive();
}
