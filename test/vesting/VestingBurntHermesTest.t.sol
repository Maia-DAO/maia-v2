// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {stdError} from "forge-std/StdError.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {DateTimeLib} from "solady/utils/DateTimeLib.sol";

import {VestingBurntHermes, ERC20} from "@maia/vesting/VestingBurntHermes.sol";
import {Maia} from "@maia/tokens/Maia.sol";
import {IBaseVault} from "@maia/interfaces/IBaseVault.sol";
import {IERC4626PartnerManager} from "@maia/interfaces/IERC4626PartnerManager.sol";

import {BurntHermes} from "@hermes/BurntHermes.sol";
import {IUtilityManager} from "@hermes/interfaces/IUtilityManager.sol";

contract VestingBurntHermesTest is DSTestPlus {
    MockERC20 public hermes;

    VestingBurntHermes public vestingERC20;

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
        bHermes.deposit(amount, address(vestingERC20));

        vestingERC20.claim();

        assertEq(bHermes.balanceOf(address(vestingERC20)), amount);
        assertEq(bHermes.balanceOf(address(address(this))), 0);

        assertEq(vestingERC20.balanceOf(address(this)), amount);
        assertEq(vestingERC20.totalSupply(), amount);
        assertEq(bHermes.gaugeWeight().balanceOf(address(this)), amount);
        assertEq(bHermes.gaugeBoost().balanceOf(address(this)), amount);
        assertEq(bHermes.governance().balanceOf(address(this)), amount);
    }

    function testVestingClaimZero() public {
        vestingERC20.claim();

        assertEq(bHermes.balanceOf(address(vestingERC20)), 0);
        assertEq(bHermes.balanceOf(address(address(this))), 0);

        assertEq(vestingERC20.balanceOf(address(this)), 0);
        assertEq(vestingERC20.totalSupply(), 0);
        assertEq(bHermes.gaugeWeight().balanceOf(address(this)), 0);
        assertEq(bHermes.gaugeBoost().balanceOf(address(this)), 0);
        assertEq(bHermes.governance().balanceOf(address(this)), 0);
    }

    function testVestingForfeit(uint128 _amount, uint128 _amountForfeit) public {
        testVestingClaim(uint248(_amount) + uint248(_amountForfeit));

        uint256 amount = uint256(_amountForfeit) + 1;

        bHermes.gaugeWeight().approve(address(vestingERC20), amount);
        bHermes.gaugeBoost().approve(address(vestingERC20), amount);
        bHermes.governance().approve(address(vestingERC20), amount);

        vestingERC20.forfeit(amount);

        uint256 amountInVesting = _amount;

        assertEq(bHermes.balanceOf(address(vestingERC20)), amountInVesting);
        assertEq(bHermes.balanceOf(address(address(this))), amount);

        assertEq(vestingERC20.balanceOf(address(this)), amountInVesting);
        assertEq(vestingERC20.totalSupply(), amountInVesting);

        assertEq(bHermes.gaugeWeight().balanceOf(address(this)), amountInVesting);
        assertEq(bHermes.gaugeBoost().balanceOf(address(this)), amountInVesting);
        assertEq(bHermes.governance().balanceOf(address(this)), amountInVesting);
    }

    function testVestingForfeitAll(uint96 _amount) public {
        testVestingForfeit(0, _amount);
    }

    function testVestingForfeitZero() public {
        hevm.expectRevert(VestingBurntHermes.AmountIsZero.selector);
        vestingERC20.forfeit(0);
    }

    function testVestingForfeitNoBalance(uint248 _amount) public {
        uint256 amount = uint256(_amount) + 1;

        hevm.expectRevert(stdError.arithmeticError);
        vestingERC20.forfeit(amount);
    }
}
