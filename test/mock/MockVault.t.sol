// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {BurntHermes} from "@hermes/BurntHermes.sol";

import {IBaseVault} from "@maia/interfaces/IBaseVault.sol";

contract MockVault is IBaseVault {
    address public partner;
    BurntHermes public bHermes;

    constructor(BurntHermes _bHermes) {
        bHermes = _bHermes;
    }

    function setPartner(address _partner) external {
        partner = _partner;
    }

    function applyWeight() public override {
        uint256 amount = bHermes.gaugeWeight().balanceOf(partner);
        bHermes.gaugeWeight().transferFrom(partner, address(this), amount);
    }

    function applyBoost() public override {
        uint256 amount = bHermes.gaugeBoost().balanceOf(partner);
        bHermes.gaugeBoost().transferFrom(partner, address(this), amount);
    }

    function applyGovernance() public override {
        uint256 amount = bHermes.governance().balanceOf(partner);
        bHermes.governance().transferFrom(partner, address(this), amount);
    }

    function applyAll() external override {
        applyWeight();
        applyBoost();
        applyGovernance();
    }

    function clearWeight(uint256 amount) public override {
        bHermes.gaugeWeight().transfer(partner, amount);
    }

    function clearBoost(uint256 amount) public override {
        bHermes.gaugeBoost().transfer(partner, amount);
    }

    function clearGovernance(uint256 amount) public override {
        bHermes.governance().transfer(partner, amount);
    }

    function clearAll() external virtual override {
        clearWeight(bHermes.gaugeWeight().balanceOf(address(this)));
        clearBoost(bHermes.gaugeBoost().balanceOf(address(this)));
        clearGovernance(bHermes.governance().balanceOf(address(this)));
    }
}

contract EvilMockVault is MockVault {
    constructor(BurntHermes _bHermes) MockVault(_bHermes) {}

    // Clear all won't do anything.
    function clearAll() external virtual override {}
}
