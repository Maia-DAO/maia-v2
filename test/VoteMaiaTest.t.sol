// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {DateTimeLib} from "solady/utils/DateTimeLib.sol";

import {VoteMaia, PartnerManagerFactory, ERC20} from "@maia/VoteMaia.sol";
import {Maia} from "@maia/tokens/Maia.sol";
import {IBaseVault} from "@maia/interfaces/IBaseVault.sol";
import {IERC4626PartnerManager} from "@maia/interfaces/IERC4626PartnerManager.sol";

import {BurntHermes} from "@hermes/BurntHermes.sol";
import {IUtilityManager} from "@hermes/interfaces/IUtilityManager.sol";

import {MockVault} from "./mock/MockVault.t.sol";

contract VoteMaiaTest is DSTestPlus {
    MockVault vault;

    MockERC20 public hermes;

    Maia public maia;

    VoteMaia public vMaia;

    uint256 bHermesRate;

    BurntHermes public bHermes;

    function setUp() public {
        // 1 jan 2023
        hevm.warp(1672531200);

        hermes = new MockERC20("test hermes", "RTKN", 18);
        maia = new Maia(address(this));

        bHermes = new BurntHermes(hermes, address(this), address(this));

        bHermesRate = 1 ether;

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
    }

    function getFirstDayOfNextMonthUnix() private view returns (uint256) {
        (uint256 currentYear, uint256 currentMonth,) = DateTimeLib.epochDayToDate(block.timestamp / 86400);

        uint256 nextMonth = currentMonth + 1;

        if (nextMonth > 12) {
            nextMonth = 1;
            currentYear++;
        }

        console2.log(currentYear, nextMonth);

        return DateTimeLib.nthWeekdayInMonthOfYearTimestamp(currentYear, nextMonth, 1, 1) + 1 days + 1;
    }

    function testDepositMaia() public {
        assertEq(vMaia.bHermesRate(), bHermesRate);

        uint256 amount = 100 ether;

        hermes.mint(address(this), 1000 ether);
        hermes.approve(address(bHermes), 1000 ether);
        bHermes.deposit(1000 ether, address(this));

        bHermes.transfer(address(vMaia), 1000 ether);

        maia.mint(address(this), amount);
        maia.approve(address(vMaia), amount);

        vMaia.deposit(amount, address(this));

        assertEq(maia.balanceOf(address(vMaia)), amount);
        assertEq(vMaia.balanceOf(address(this)), amount);
    }

    function testDepositMaiaPartnerGovernanceSupply() public {
        testDepositMaia();
        uint256 amount = vMaia.balanceOf(address(this));
        maia.approve(address(vMaia), type(uint256).max);

        // fast-forward to withdrawal Tuesday
        hevm.warp(getFirstDayOfNextMonthUnix());

        for (uint256 i = 0; i < 10; i++) {
            // Assert that the partner governance supply is equal to VoteMaia total supply
            assertEq(vMaia.totalSupply(), vMaia.partnerGovernance().totalSupply());

            // dilute pbHermes by withdraw & deposit cycle
            vMaia.withdraw(amount, address(this), address(this));
            vMaia.deposit(amount, address(this));
        }
    }

    function testDepositMaiaAmountFail() public {
        assertEq(vMaia.bHermesRate(), bHermesRate);

        uint256 amount = 100 ether;

        maia.mint(address(this), amount);
        maia.approve(address(vMaia), amount);

        hevm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        vMaia.deposit(101 ether, address(this));
    }

    function testWithdrawMaia() public {
        testDepositMaia();

        uint256 amount = 100 ether;

        hevm.warp(getFirstDayOfNextMonthUnix());

        vMaia.withdraw(amount, address(this), address(this));

        assertEq(maia.balanceOf(address(vMaia)), 0);
        assertEq(vMaia.balanceOf(address(this)), 0);
    }

    function testWithdrawMaiaPeriodFail() public {
        testDepositMaia();

        uint256 amount = 100 ether;

        hevm.expectRevert(abi.encodeWithSignature("UnstakePeriodNotLive()"));
        vMaia.withdraw(amount, address(this), address(this));
    }

    function testWithdrawMaiaOverPeriodFail() public {
        testDepositMaia();

        uint256 amount = 100 ether;

        hevm.warp(getFirstDayOfNextMonthUnix() + 1 days);

        hevm.expectRevert(abi.encodeWithSignature("UnstakePeriodNotLive()"));
        vMaia.withdraw(amount, address(this), address(this));
    }

    function increaseConversionRate(uint256 newRate, bool deposit) private {
        if (deposit) testDepositMaia();

        bool shouldPass = true;
        if (newRate <= vMaia.bHermesRate()) {
            shouldPass = false;
            hevm.expectRevert(IERC4626PartnerManager.InvalidRate.selector);
        } else if (
            vMaia.totalSupply() > 0 && newRate > (bHermes.balanceOf(address(vMaia)) / vMaia.totalSupply()) * 1 ether
        ) {
            shouldPass = false;
            hevm.expectRevert(IERC4626PartnerManager.InsufficientBacking.selector);
        }

        vMaia.increaseConversionRate(newRate);

        if (shouldPass) {
            assertEq(vMaia.bHermesRate(), newRate);
            bHermesRate = newRate;
        }
    }

    function testIncreaseConversionRate(uint256 newRate) public {
        // totalSupply can't be zero
        increaseConversionRate(newRate, true);
    }

    function testClaimAfterIncreaseConversionRate() public {
        increaseConversionRate(1.2 ether, true);

        vMaia.totalSupply();

        vMaia.gaugeWeight().approve(address(vMaia), type(uint256).max);
        vMaia.governance().approve(address(vMaia), type(uint256).max);
        vMaia.partnerGovernance().approve(address(vMaia), type(uint256).max);

        uint256 amount = 100 ether;
        uint256 expect = amount * bHermesRate / 1 ether;

        // claim Weight
        vMaia.claimWeight(expect);
        assertEq(expect, ERC20(vMaia.gaugeWeight()).balanceOf(address(this)));

        // claim Governance
        vMaia.claimGovernance(expect);
        assertEq(expect, ERC20(vMaia.governance()).balanceOf(address(this)));

        // claim PartnerGovernance
        vMaia.claimPartnerGovernance(expect);
        assertEq(expect, ERC20(vMaia.partnerGovernance()).balanceOf(address(this)));
    }

    function testDepositMaiaClaim() public {
        increaseConversionRate(2, true);

        vMaia.claimOutstanding();

        // got utility tokens as expected
        assertGt(vMaia.bHermes().gaugeWeight().balanceOf(address(this)), 0);
        assertGt(vMaia.bHermes().governance().balanceOf(address(this)), 0);
        assertGt(vMaia.partnerGovernance().balanceOf(address(this)), 0);

        vMaia.gaugeWeight().approve(address(vMaia), type(uint256).max);
        vMaia.governance().approve(address(vMaia), type(uint256).max);
        vMaia.partnerGovernance().approve(address(vMaia), type(uint256).max);

        vMaia.forfeitOutstanding();

        assertEq(vMaia.bHermes().gaugeWeight().balanceOf(address(this)), 0);
        assertEq(vMaia.bHermes().governance().balanceOf(address(this)), 0);
        assertEq(vMaia.partnerGovernance().balanceOf(address(this)), 0);
    }

    function testMax() public {
        testDepositMaia();

        uint256 amount = 100 ether;

        hevm.warp(getFirstDayOfNextMonthUnix());

        assertEq(vMaia.maxWithdraw(address(this)), amount);
        assertEq(vMaia.maxRedeem(address(this)), amount);
    }

    function testMaxNotFirstTuesday() public {
        testDepositMaia();

        hevm.warp(getFirstDayOfNextMonthUnix() + 1 days);

        assertEq(vMaia.maxWithdraw(address(this)), 0);
        assertEq(vMaia.maxRedeem(address(this)), 0);
    }

    function testClaimMultiple() public {
        testDepositMaia();

        uint256 amount = 100 ether;

        hevm.warp(getFirstDayOfNextMonthUnix());

        vMaia.claimMultiple(amount);

        assertEq(vMaia.bHermes().gaugeWeight().balanceOf(address(this)), amount);
        assertEq(vMaia.bHermes().governance().balanceOf(address(this)), amount);
        assertEq(vMaia.partnerGovernance().balanceOf(address(this)), amount);
    }

    function testClaimMultipleAmounts() public {
        testDepositMaia();

        uint256 amount = 100 ether;

        hevm.warp(getFirstDayOfNextMonthUnix());

        vMaia.claimMultipleAmounts(amount, amount, amount, amount);

        assertEq(vMaia.bHermes().gaugeWeight().balanceOf(address(this)), amount);
        assertEq(vMaia.bHermes().governance().balanceOf(address(this)), amount);
        assertEq(vMaia.partnerGovernance().balanceOf(address(this)), amount);
    }

    function testClaimWeight() public {
        testDepositMaia();

        uint256 amount = 100 ether;

        hevm.warp(getFirstDayOfNextMonthUnix());

        vMaia.claimWeight(amount);

        assertEq(vMaia.bHermes().gaugeWeight().balanceOf(address(this)), amount);
    }

    function testClaimGovernance() public {
        testDepositMaia();

        uint256 amount = 100 ether;

        hevm.warp(getFirstDayOfNextMonthUnix());

        vMaia.claimGovernance(amount);

        assertEq(vMaia.governance().balanceOf(address(this)), amount);
    }

    function testForfeitMultiple() public {
        testClaimMultiple();

        uint256 amount = 100 ether;

        vMaia.bHermes().gaugeWeight().approve(address(vMaia), amount);
        vMaia.bHermes().governance().approve(address(vMaia), amount);
        vMaia.partnerGovernance().approve(address(vMaia), amount);

        vMaia.forfeitMultiple(amount);

        assertEq(vMaia.bHermes().gaugeWeight().balanceOf(address(this)), 0);
        assertEq(vMaia.bHermes().governance().balanceOf(address(this)), 0);
        assertEq(vMaia.partnerGovernance().balanceOf(address(this)), 0);
    }

    function testForfeitMultipleAmounts() public {
        testClaimMultiple();

        uint256 amount = 100 ether;

        vMaia.bHermes().gaugeWeight().approve(address(vMaia), amount);
        vMaia.bHermes().governance().approve(address(vMaia), amount);
        vMaia.partnerGovernance().approve(address(vMaia), amount);

        vMaia.forfeitMultipleAmounts(amount, amount, amount, amount);

        assertEq(vMaia.bHermes().gaugeWeight().balanceOf(address(this)), 0);
        assertEq(vMaia.bHermes().governance().balanceOf(address(this)), 0);
        assertEq(vMaia.partnerGovernance().balanceOf(address(this)), 0);
    }

    function testForfeitWeight() public {
        testClaimWeight();

        uint256 amount = 100 ether;

        vMaia.bHermes().gaugeWeight().approve(address(vMaia), amount);

        vMaia.forfeitWeight(amount);

        assertEq(vMaia.bHermes().gaugeWeight().balanceOf(address(this)), 0);
    }

    function testForfeitGovernance() public {
        testClaimGovernance();

        uint256 amount = 100 ether;

        vMaia.governance().approve(address(vMaia), amount);

        vMaia.forfeitGovernance(amount);

        assertEq(vMaia.governance().balanceOf(address(this)), 0);
    }

    function testClaimForfeitClaim() public {
        testForfeitMultiple();

        uint256 amount = 100 ether;

        vMaia.claimMultiple(amount);

        assertEq(vMaia.bHermes().gaugeWeight().balanceOf(address(this)), amount);
        assertEq(vMaia.bHermes().governance().balanceOf(address(this)), amount);
        assertEq(vMaia.partnerGovernance().balanceOf(address(this)), amount);
    }

    function testMintMaia(address account, uint256 amount) public {
        maia.mint(account, amount);

        assertEq(maia.balanceOf(account), amount);
        assertEq(maia.totalSupply(), amount);
    }

    function testMintMaiaNotOwner(address account, uint256 amount) public {
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        hevm.prank(address(1));
        maia.mint(account, amount);
    }
}
