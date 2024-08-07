// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {DateTimeLib} from "solady/utils/DateTimeLib.sol";

import {VestingBurntHermes, ERC20} from "@maia/VestingBurntHermes.sol";
import {Maia} from "@maia/tokens/Maia.sol";
import {IBaseVault} from "@maia/interfaces/IBaseVault.sol";
import {IERC4626PartnerManager} from "@maia/interfaces/IERC4626PartnerManager.sol";

import {BurntHermes} from "@hermes/BurntHermes.sol";
import {IUtilityManager} from "@hermes/interfaces/IUtilityManager.sol";

import {MockVault} from "./mock/MockVault.t.sol";

contract VestingBurntHermesTest is DSTestPlus {
    MockERC20 public hermes;

    VestingBurntHermes public vestingERC20;

    uint256 bHermesRate;

    BurntHermes public bHermes;

    function setUp() public {
        hermes = new MockERC20("test hermes", "RTKN", 18);

        bHermes = new BurntHermes(hermes, address(this), address(this));

        vestingERC20 = new VestingBurntHermes(bHermes, address(this));
    }

    function testVestingClaim(uint248 _amount) public {
        uint256 amount = uint256(_amount) + 1;

        hermes.mint(address(this), amount);
        hermes.approve(address(bHermes), amount);
        bHermes.deposit(amount, address(this));

        bHermes.transfer(address(vestingERC20), amount);

        vestingERC20.claim();

        assertEq(bHermes.balanceOf(address(vestingERC20)), amount);
        assertEq(bHermes.balanceOf(address(address(this))), 0);

        assertEq(vestingERC20.balanceOf(address(this)), amount);
        assertEq(vestingERC20.totalSupply(), amount);
        assertEq(bHermes.gaugeWeight().balanceOf(address(this)), amount);
        assertEq(bHermes.gaugeBoost().balanceOf(address(this)), amount);
        assertEq(bHermes.governance().balanceOf(address(this)), amount);
    }

    function testVestingForfeit(uint248 _amount) public {
        testVestingClaim(_amount);

        uint256 amount = uint256(_amount) + 1;

        bHermes.gaugeWeight().approve(address(vestingERC20), amount);
        bHermes.gaugeBoost().approve(address(vestingERC20), amount);
        bHermes.governance().approve(address(vestingERC20), amount);

        vestingERC20.forfeit(amount);

        assertEq(bHermes.balanceOf(address(vestingERC20)), 0);
        assertEq(bHermes.balanceOf(address(address(this))), amount);

        assertEq(vestingERC20.balanceOf(address(this)), 0);
        assertEq(vestingERC20.totalSupply(), 0);
        assertEq(bHermes.gaugeWeight().balanceOf(address(this)), 0);
        assertEq(bHermes.gaugeBoost().balanceOf(address(this)), 0);
        assertEq(bHermes.governance().balanceOf(address(this)), 0);
    }
}
