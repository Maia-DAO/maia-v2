// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {stdError} from "forge-std/StdError.sol";

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {DateTimeLib} from "solady/utils/DateTimeLib.sol";

import {VestingVoteMaia, ERC20} from "@maia/vesting/VestingVoteMaia.sol";
import {VoteMaia, PartnerManagerFactory} from "@maia/VoteMaia.sol";
import {Maia} from "@maia/tokens/Maia.sol";
import {IBaseVault} from "@maia/interfaces/IBaseVault.sol";
import {IERC4626PartnerManager} from "@maia/interfaces/IERC4626PartnerManager.sol";

import {BurntHermes} from "@hermes/BurntHermes.sol";
import {IUtilityManager} from "@hermes/interfaces/IUtilityManager.sol";

import {MockVault} from "../mock/MockVault.t.sol";

contract VestingVoteMaiaTest is DSTestPlus {
    using FixedPointMathLib for uint256;

    MockVault vault;

    MockERC20 public hermes;

    Maia public maia;

    VoteMaia public vMaia;

    uint256 bHermesRate;

    VestingVoteMaia public vestingERC20;

    BurntHermes public bHermes;

    function setUp() public {
        hermes = new MockERC20("test hermes", "RTKN", 18);
        maia = new Maia(address(this));

        bHermes = new BurntHermes(hermes, address(this), address(this));

        bHermesRate = 10 ether;

        vault = new MockVault(bHermes);

        vMaia = new VoteMaia(
            PartnerManagerFactory(address(this)),
            bHermesRate,
            maia,
            "Vote Maia",
            "vMAIA",
            address(bHermes),
            address(vault),
            address(this) // set owner to allow call to 'increaseConversionRate'
        );

        vault.setPartner(address(vMaia));

        vestingERC20 = new VestingVoteMaia(vMaia, address(this));
    }

    function testVestingClaim(uint128 _amount) public {
        uint256 amount = uint256(_amount) + 1;

        uint256 amountToBurn = amount.mulWad(bHermesRate);

        hermes.mint(address(this), amountToBurn);
        hermes.approve(address(bHermes), amountToBurn);
        bHermes.deposit(amountToBurn, address(vMaia));

        maia.mint(address(this), amount);
        maia.approve(address(vMaia), amount);

        vMaia.deposit(amount, address(vestingERC20));

        vestingERC20.claim();

        assertEq(vMaia.balanceOf(address(vestingERC20)), amount);
        assertEq(vMaia.balanceOf(address(address(this))), 0);

        assertEq(vestingERC20.balanceOf(address(this)), amount);
        assertEq(vestingERC20.totalSupply(), amount);
        assertEq(vMaia.gaugeWeight().balanceOf(address(this)), amountToBurn);
        assertEq(vMaia.governance().balanceOf(address(this)), amountToBurn);
        assertEq(vMaia.partnerGovernance().balanceOf(address(this)), amountToBurn);
    }

    function testVestingClaimZero() public {
        vestingERC20.claim();

        assertEq(vMaia.balanceOf(address(vestingERC20)), 0);
        assertEq(vMaia.balanceOf(address(address(this))), 0);

        assertEq(vestingERC20.balanceOf(address(this)), 0);
        assertEq(vestingERC20.totalSupply(), 0);
        assertEq(vMaia.gaugeWeight().balanceOf(address(this)), 0);
        assertEq(vMaia.governance().balanceOf(address(this)), 0);
        assertEq(vMaia.partnerGovernance().balanceOf(address(this)), 0);
    }

    function testVestingForfeit(uint96 _amount, uint96 _amountForfeit) public {
        testVestingClaim(uint128(_amount) + uint128(_amountForfeit));

        uint256 amount = uint256(_amountForfeit) + 1;
        uint256 amountToApprove = amount.mulWad(bHermesRate);

        vMaia.gaugeWeight().approve(address(vestingERC20), amountToApprove);
        vMaia.governance().approve(address(vestingERC20), amountToApprove);
        vMaia.partnerGovernance().approve(address(vestingERC20), amountToApprove);

        vestingERC20.forfeit(amount);

        uint256 amountInVesting = _amount;
        uint256 utilityAmountInVesting = amountInVesting.mulWad(bHermesRate);

        assertEq(vMaia.balanceOf(address(vestingERC20)), amountInVesting);
        assertEq(vMaia.balanceOf(address(address(this))), amount);

        assertEq(vestingERC20.balanceOf(address(this)), amountInVesting);
        assertEq(vestingERC20.totalSupply(), amountInVesting);

        assertEq(vMaia.gaugeWeight().balanceOf(address(this)), utilityAmountInVesting);
        assertEq(vMaia.governance().balanceOf(address(this)), utilityAmountInVesting);
        assertEq(vMaia.partnerGovernance().balanceOf(address(this)), utilityAmountInVesting);
    }

    function testVestingForfeitAll(uint96 _amount) public {
        testVestingForfeit(0, _amount);
    }

    function testVestingForfeitZero() public {
        hevm.expectRevert(VestingVoteMaia.AmountIsZero.selector);
        vestingERC20.forfeit(0);
    }

    function testVestingForfeitNoBalance(uint128 _amount) public {
        uint256 amount = uint256(_amount) + 1;

        hevm.expectRevert(stdError.arithmeticError);
        vestingERC20.forfeit(amount);
    }
}
