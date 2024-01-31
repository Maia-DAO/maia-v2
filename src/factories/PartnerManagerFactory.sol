// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {IBaseVault} from "../interfaces/IBaseVault.sol";
import {IPartnerManagerFactory} from "../interfaces/IPartnerManagerFactory.sol";
import {ERC4626PartnerManager as PartnerManager} from "../tokens/ERC4626PartnerManager.sol";

/// @title Factory for managing PartnerManagers
contract PartnerManagerFactory is Ownable, IPartnerManagerFactory {
    /*//////////////////////////////////////////////////////////////
                         PARTNER MANAGER STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPartnerManagerFactory
    address public immutable override bHermes;

    /// @inheritdoc IPartnerManagerFactory
    PartnerManager[] public override partners;

    /// @inheritdoc IPartnerManagerFactory
    IBaseVault[] public override vaults;

    /// @inheritdoc IPartnerManagerFactory
    mapping(PartnerManager partner => uint256 partnerId) public override partnerIds;

    /// @inheritdoc IPartnerManagerFactory
    mapping(IBaseVault vault => uint256 vaultId) public override vaultIds;

    /**
     * @notice Initializes the contract with the owner and BurntHermes token.
     * @param _bHermes The address of the BurntHermes token.
     * @param _owner The owner of the contract.
     */
    constructor(address _bHermes, address _owner) {
        _initializeOwner(_owner);
        bHermes = _bHermes;
        partners.push(PartnerManager(address(0)));
        vaults.push(IBaseVault(address(0)));
    }

    /// @notice Function being overridden to prevent mistakenly renouncing ownership.
    function renounceOwnership() public payable override {
        revert RenounceOwnershipNotAllowed();
    }

    /// @inheritdoc IPartnerManagerFactory
    function getPartners() external view override returns (PartnerManager[] memory) {
        return partners;
    }

    /// @inheritdoc IPartnerManagerFactory
    function getVaults() external view override returns (IBaseVault[] memory) {
        return vaults;
    }

    /*//////////////////////////////////////////////////////////////
                        NEW PARTNER LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPartnerManagerFactory
    function addPartner(PartnerManager newPartnerManager) external override onlyOwner {
        if (partners[partnerIds[newPartnerManager]] == newPartnerManager) revert InvalidPartnerManager();
        uint256 id = partners.length;
        partners.push(newPartnerManager);
        partnerIds[newPartnerManager] = id;

        emit AddedPartner(newPartnerManager, id);
    }

    /// @inheritdoc IPartnerManagerFactory
    function addVault(IBaseVault newVault) external override onlyOwner {
        if (vaults[vaultIds[newVault]] == newVault) revert InvalidVault();
        uint256 id = vaults.length;
        vaults.push(newVault);
        vaultIds[newVault] = id;

        emit AddedVault(newVault, id);
    }

    /*//////////////////////////////////////////////////////////////
                        MIGRATION LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPartnerManagerFactory
    function removePartner(PartnerManager partnerManager) external override onlyOwner {
        if (partners[partnerIds[partnerManager]] != partnerManager) revert InvalidPartnerManager();
        delete partners[partnerIds[partnerManager]];
        delete partnerIds[partnerManager];

        emit RemovedPartner(partnerManager);
    }

    /// @inheritdoc IPartnerManagerFactory
    function removeVault(IBaseVault vault) external override onlyOwner {
        if (vaults[vaultIds[vault]] != vault) revert InvalidVault();
        delete vaults[vaultIds[vault]];
        delete vaultIds[vault];

        emit RemovedVault(vault);
    }
}
