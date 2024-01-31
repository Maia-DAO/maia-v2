// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20Votes, UtilityManager, IUtilityManager} from "@hermes/UtilityManager.sol";

import {IBaseVault} from "./interfaces/IBaseVault.sol";
import {IPartnerUtilityManager} from "./interfaces/IPartnerUtilityManager.sol";

/// @title Partner Utility Tokens Manager Contract
abstract contract PartnerUtilityManager is UtilityManager, IPartnerUtilityManager {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                         UTILITY MANAGER STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPartnerUtilityManager
    address public override partnerVault;

    /// @inheritdoc IPartnerUtilityManager
    ERC20Votes public immutable override partnerGovernance;

    /// @inheritdoc IPartnerUtilityManager
    mapping(address user => uint256 claimedPartnerGovernance) public override userClaimedPartnerGovernance;

    /**
     * @notice Constructs the Utility Manager Contract.
     * @param _gaugeWeight The address of the weight gauge.
     * @param _gaugeBoost The address of the boost gauge.
     * @param _governance The address of the governance token.
     * @param _partnerGovernance The address of the partner governance token.
     * @param _partnerVault The address of the partner vault.
     */
    constructor(
        address _gaugeWeight,
        address _gaugeBoost,
        address _governance,
        address _partnerGovernance,
        address _partnerVault
    ) UtilityManager(_gaugeWeight, _gaugeBoost, _governance) {
        partnerGovernance = ERC20Votes(_partnerGovernance);
        partnerVault = _partnerVault;

        address(gaugeWeight).safeApprove(partnerVault, type(uint256).max);
        address(gaugeBoost).safeApprove(partnerVault, type(uint256).max);
        address(governance).safeApprove(partnerVault, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                        UTILITY TOKENS LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUtilityManager
    function forfeitMultiple(uint256 amount) public virtual override {
        forfeitWeight(amount);
        forfeitBoost(amount);
        forfeitGovernance(amount);
        forfeitPartnerGovernance(amount);
    }

    /// @inheritdoc IPartnerUtilityManager
    function forfeitMultipleAmounts(uint256 weight, uint256 boost, uint256 _governance, uint256 _partnerGovernance)
        public
        virtual
        override
    {
        forfeitWeight(weight);
        forfeitBoost(boost);
        forfeitGovernance(_governance);
        forfeitPartnerGovernance(_partnerGovernance);
    }

    /// @inheritdoc IUtilityManager
    function forfeitWeight(uint256 amount) public virtual override {
        super.forfeitWeight(amount);

        // Save partnerVault to memory
        address _partnerVault = partnerVault;

        /// @dev Vault applies outstanding weight.
        if (_partnerVault != address(0)) {
            IBaseVault(_partnerVault).applyWeight();
        }
    }

    /// @inheritdoc IUtilityManager
    function forfeitBoost(uint256 amount) public virtual override {
        super.forfeitBoost(amount);

        // Save partnerVault to memory
        address _partnerVault = partnerVault;

        /// @dev Vault applies outstanding boost.
        if (_partnerVault != address(0)) {
            IBaseVault(_partnerVault).applyBoost();
        }
    }

    /// @inheritdoc IUtilityManager
    function forfeitGovernance(uint256 amount) public virtual override {
        super.forfeitGovernance(amount);

        // Save partnerVault to memory
        address _partnerVault = partnerVault;

        /// @dev Vault applies outstanding governance.
        if (_partnerVault != address(0)) {
            IBaseVault(_partnerVault).applyGovernance();
        }
    }

    /// @inheritdoc IPartnerUtilityManager
    function forfeitPartnerGovernance(uint256 amount) public override {
        userClaimedPartnerGovernance[msg.sender] -= amount;
        /// @dev partnerGovernance is kept in this contract and not sent to vaults to avoid governance attacks.
        address(partnerGovernance).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IUtilityManager
    function claimMultiple(uint256 amount) public virtual override {
        claimWeight(amount);
        claimBoost(amount);
        claimGovernance(amount);
        claimPartnerGovernance(amount);
    }

    /// @inheritdoc IPartnerUtilityManager
    function claimMultipleAmounts(uint256 weight, uint256 boost, uint256 _governance, uint256 _partnerGovernance)
        public
        virtual
        override
    {
        claimWeight(weight);
        claimBoost(boost);
        claimGovernance(_governance);
        claimPartnerGovernance(_partnerGovernance);
    }

    /// @inheritdoc IUtilityManager
    function claimWeight(uint256 amount) public virtual override checkWeight(amount) {
        uint256 weightAvailable = address(gaugeWeight).balanceOf(address(this));
        /// @dev Must transfer weight amount to this manager address.
        if (weightAvailable < amount) {
            IBaseVault(partnerVault).clearWeight(amount - weightAvailable);
        }

        super.claimWeight(amount);
    }

    /// @inheritdoc IUtilityManager
    function claimBoost(uint256 amount) public virtual override checkBoost(amount) {
        uint256 boostAvailable = address(gaugeBoost).balanceOf(address(this));
        /// @dev Must transfer boost amount to this manager address.
        if (boostAvailable < amount) IBaseVault(partnerVault).clearBoost(amount - boostAvailable);

        super.claimBoost(amount);
    }

    /// @inheritdoc IUtilityManager
    function claimGovernance(uint256 amount) public virtual override checkGovernance(amount) {
        uint256 governanceAvailable = address(governance).balanceOf(address(this));
        /// @dev Must transfer governance amount to this manager address.
        if (governanceAvailable < amount) {
            IBaseVault(partnerVault).clearGovernance(amount - governanceAvailable);
        }

        super.claimGovernance(amount);
    }

    /// @inheritdoc IPartnerUtilityManager
    function claimPartnerGovernance(uint256 amount) public override checkPartnerGovernance(amount) {
        if (amount == 0) return;
        userClaimedPartnerGovernance[msg.sender] += amount;
        address(partnerGovernance).safeTransfer(msg.sender, amount);

        emit ClaimPartnerGovernance(msg.sender, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    /// @dev Checks available governance allows for call.
    modifier checkPartnerGovernance(uint256 amount) virtual;
}
