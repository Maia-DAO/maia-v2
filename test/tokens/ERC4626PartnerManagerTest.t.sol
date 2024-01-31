// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {ERC4626} from "@ERC4626/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {console2} from "forge-std/console2.sol";

import {MockERC4626PartnerManager, IERC4626PartnerManager} from "../mock/MockERC4626PartnerManager.t.sol";
import {MockVault, EvilMockVault} from "../mock/MockVault.t.sol";

import {PartnerManagerFactory, IPartnerManagerFactory} from "@maia/factories/PartnerManagerFactory.sol";
import {PartnerUtilityManager} from "@maia/PartnerUtilityManager.sol";

import {BurntHermes} from "@hermes/BurntHermes.sol";
import {bHermesVotes as ERC20MultiVotes} from "@hermes/tokens/bHermesVotes.sol";

contract ERC4626PartnerManagerTest is DSTestPlus {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    MockERC4626PartnerManager public manager;

    MockVault vault;
    EvilMockVault evilVault;

    MockERC20 public hermes;

    MockERC20 public partnerAsset;

    uint256 bHermesRate;

    BurntHermes public _bHermes;

    PartnerManagerFactory public factory;

    function setUp() public {
        hermes = new MockERC20("test hermes", "RTKN", 18);

        partnerAsset = new MockERC20("test partnerAsset", "tpartnerAsset", 18);

        _bHermes = new BurntHermes(hermes, address(this), address(this));

        bHermesRate = 1 ether;

        vault = new MockVault(_bHermes);
        evilVault = new EvilMockVault(_bHermes);

        factory = new PartnerManagerFactory(address(_bHermes), address(this));

        manager = new MockERC4626PartnerManager(
            factory,
            bHermesRate,
            partnerAsset,
            "test partner manager",
            "PartnerFi",
            address(_bHermes),
            address(vault),
            address(this)
        );

        factory.addPartner(manager);
        factory.addVault(vault);
        factory.addVault(evilVault);

        vault.setPartner(address(manager));
        evilVault.setPartner(address(manager));
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function testDeposit() public {
        assertEq(manager.bHermesRate(), bHermesRate);

        uint256 amount = 100 ether;

        hermes.mint(address(this), 1000 ether);
        hermes.approve(address(_bHermes), 1000 ether);
        _bHermes.deposit(1000 ether, address(this));

        _bHermes.transfer(address(manager), 1000 ether);

        partnerAsset.mint(address(this), amount);
        partnerAsset.approve(address(manager), amount);

        manager.deposit(amount, address(this));

        assertEq(partnerAsset.balanceOf(address(manager)), amount);
        assertEq(manager.balanceOf(address(this)), amount);
    }

    function testDepositTwoDeposits() public {
        testDeposit();

        assertEq(manager.bHermesRate(), bHermesRate);

        uint256 amount = 150 ether;

        hevm.startPrank(address(2));

        partnerAsset.mint(address(2), amount);
        partnerAsset.approve(address(manager), amount);

        manager.deposit(amount, address(2));

        hevm.stopPrank();

        assertEq(partnerAsset.balanceOf(address(manager)), amount + 100 ether);
        assertEq(manager.balanceOf(address(2)), amount);
    }

    function testWithdraw() public {
        testDeposit();

        uint256 amount = 100 ether;

        // hevm.warp(getFirstDayOfNextMonthUnix());

        manager.withdraw(amount, address(this), address(this));

        assertEq(partnerAsset.balanceOf(address(manager)), 0);
        assertEq(manager.balanceOf(address(this)), 0);
    }

    function testTotalAssets() public {
        testDeposit();

        require(manager.totalAssets() == 100 ether);
        require(manager.totalAssets() == manager.totalSupply());
    }

    function testConvertToShares() public view {
        require(manager.convertToShares(100 ether) == 100 ether);
    }

    function testConvertToSharesOverZeroSupply() public {
        testDepositTwoDeposits();

        require(manager.convertToShares(100 ether) == 100 ether);
    }

    function testConvertToAssets() public view {
        require(manager.convertToAssets(100 ether) == 100 ether);
    }

    function testConvertToAssetsOverZeroSupply() public {
        testDepositTwoDeposits();

        require(manager.convertToAssets(100 ether) == 100 ether);
    }

    function testPreviewDeposit() public view {
        require(manager.previewDeposit(100 ether) == 100 ether);
    }

    function testPreviewMint() public view {
        require(manager.previewMint(100 ether) == 100 ether);
    }

    function testPreviewWithdraw() public {
        testDeposit();

        require(manager.previewWithdraw(100 ether) == 100 ether);
    }

    function testPreviewRedeem() public {
        testDeposit();

        require(manager.previewRedeem(100 ether) == 100 ether);
    }

    function testMaxDeposit() public {
        require(manager.maxDeposit(address(0)) == 0);

        hermes.mint(address(this), 1000 ether);
        hermes.approve(address(_bHermes), 1000 ether);
        _bHermes.deposit(1000 ether, address(this));

        _bHermes.transfer(address(manager), 1000 ether);

        require(manager.maxDeposit(address(0)) == 1000 ether);
    }

    function testMaxMint() public {
        require(manager.maxMint(address(0)) == 0);

        hermes.mint(address(this), 1000 ether);
        hermes.approve(address(_bHermes), 1000 ether);
        _bHermes.deposit(1000 ether, address(this));

        _bHermes.transfer(address(manager), 1000 ether);

        require(manager.maxDeposit(address(0)) == 1000 ether);
    }

    function testMaxWithdraw() public {
        testDeposit();
        require(manager.maxWithdraw(address(this)) == 100 ether);
    }

    function maxRedeem() public view {
        require(manager.maxRedeem(address(this)) == 100 ether);
    }

    function testUpdateUnderlyingBalance() public {
        testDeposit();

        hermes.mint(address(this), 1000 ether);
        hermes.approve(address(_bHermes), 1000 ether);
        _bHermes.deposit(1000 ether, address(manager));

        assertEq(_bHermes.gaugeWeight().balanceOf(address(manager)), 1000 ether);
        assertEq(_bHermes.gaugeBoost().balanceOf(address(manager)), 1000 ether);
        assertEq(_bHermes.governance().balanceOf(address(manager)), 1000 ether);

        manager.updateUnderlyingBalance();

        assertEq(_bHermes.gaugeWeight().balanceOf(address(manager)), 2000 ether);
        assertEq(_bHermes.gaugeBoost().balanceOf(address(manager)), 2000 ether);
        assertEq(_bHermes.governance().balanceOf(address(manager)), 2000 ether);
    }

    function testClaimOutstanding() public {
        testUpdateUnderlyingBalance();

        assertEq(_bHermes.gaugeWeight().balanceOf(address(manager)), 2000 ether);
        assertEq(_bHermes.gaugeBoost().balanceOf(address(manager)), 2000 ether);
        assertEq(_bHermes.governance().balanceOf(address(manager)), 2000 ether);

        manager.claimOutstanding();

        uint256 amount = 100 ether;

        assertEq(_bHermes.gaugeWeight().balanceOf(address(manager)), 2000 ether - amount);
        assertEq(_bHermes.gaugeBoost().balanceOf(address(manager)), 2000 ether - amount);
        assertEq(_bHermes.governance().balanceOf(address(manager)), 2000 ether - amount);
    }

    function testClaimBoost() public {
        testUpdateUnderlyingBalance();

        assertEq(_bHermes.gaugeBoost().balanceOf(address(manager)), 2000 ether);

        manager.claimBoost(100 ether);

        assertEq(_bHermes.gaugeBoost().balanceOf(address(manager)), 2000 ether - 100 ether);
    }

    function testForfeitBoost() public {
        testClaimBoost();

        assertEq(_bHermes.gaugeBoost().balanceOf(address(manager)), 2000 ether - 100 ether);

        _bHermes.gaugeBoost().approve(address(manager), 100 ether);
        manager.forfeitBoost(100 ether);

        assertEq(_bHermes.gaugeBoost().balanceOf(address(vault)), 2000 ether);
    }

    function testMigratePartnerVault() public {
        testUpdateUnderlyingBalance();

        vault.applyAll();

        assertEq(_bHermes.gaugeWeight().balanceOf(address(vault)), 2000 ether);
        assertEq(_bHermes.gaugeBoost().balanceOf(address(vault)), 2000 ether);
        assertEq(_bHermes.governance().balanceOf(address(vault)), 2000 ether);

        manager.migratePartnerVault(address(evilVault));

        assertEq(_bHermes.gaugeWeight().balanceOf(address(evilVault)), 2000 ether);
        assertEq(_bHermes.gaugeBoost().balanceOf(address(evilVault)), 2000 ether);
        assertEq(_bHermes.governance().balanceOf(address(evilVault)), 2000 ether);
    }

    function testMigratePartnerVaultUserFundsExistInOldVault() public {
        testMigratePartnerVault();

        hevm.expectRevert(IERC4626PartnerManager.UserFundsExistInOldVault.selector);
        manager.migratePartnerVault(address(evilVault));
    }

    function testMigratePartnerVaultZeroAddress() public {
        testUpdateUnderlyingBalance();

        vault.applyAll();

        assertEq(_bHermes.gaugeWeight().balanceOf(address(vault)), 2000 ether);
        assertEq(_bHermes.gaugeBoost().balanceOf(address(vault)), 2000 ether);
        assertEq(_bHermes.governance().balanceOf(address(vault)), 2000 ether);

        manager.migratePartnerVault(address(0));

        assertEq(_bHermes.gaugeWeight().balanceOf(address(0)), 0);
        assertEq(_bHermes.gaugeBoost().balanceOf(address(0)), 0);
        assertEq(_bHermes.governance().balanceOf(address(0)), 0);
    }

    function testMigratePartnerVaultUnrecognizedVault() public {
        testMigratePartnerVaultZeroAddress();

        testRemoveVault();

        hevm.expectRevert(IERC4626PartnerManager.UnrecognizedVault.selector);
        manager.migratePartnerVault(address(evilVault));
    }

    function testMigratePartnerVaultNotOwner() public {
        manager.transferOwnership(address(2));

        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        manager.migratePartnerVault(address(evilVault));
    }

    function testIncreaseConversionRateNotOwner() public {
        manager.transferOwnership(address(2));

        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        manager.increaseConversionRate(1 ether);
    }

    function testRemovePartner() public {
        assertEq(address(factory.getPartners()[1]), address(manager));
        assertEq(factory.getPartners().length, 2);
        assertEq(factory.partnerIds(manager), 1);

        factory.removePartner(manager);

        assertEq(address(factory.getPartners()[1]), address(0));
        assertEq(factory.getPartners().length, 2);
        assertEq(factory.partnerIds(manager), 0);
    }

    function testRemoveVault() public {
        assertEq(address(factory.getVaults()[2]), address(evilVault));
        assertEq(factory.getVaults().length, 3);
        assertEq(factory.vaultIds(evilVault), 2);

        factory.removeVault(evilVault);

        assertEq(address(factory.getVaults()[2]), address(0));
        assertEq(factory.getVaults().length, 3);
        assertEq(factory.vaultIds(evilVault), 0);
    }

    function testRenounceOwnershipNotAllowed() public {
        hevm.expectRevert(IPartnerManagerFactory.RenounceOwnershipNotAllowed.selector);
        factory.renounceOwnership();
    }

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testTransfer() public {
        testDeposit();

        manager.transfer(address(2), 100 ether);

        assertEq(manager.balanceOf(address(this)), 0);
        assertEq(manager.balanceOf(address(2)), 100 ether);
    }

    function testTransferFrom() public {
        testDeposit();

        manager.approve(address(2), 100 ether);

        hevm.prank(address(2));
        manager.transferFrom(address(this), address(2), 100 ether);

        assertEq(manager.balanceOf(address(this)), 0);
        assertEq(manager.balanceOf(address(2)), 100 ether);
    }

    function testTransferFailed() public {
        testDeposit();

        manager.claimWeight(1);

        _bHermes.gaugeWeight().transfer(address(2), 1);

        assertEq(_bHermes.gaugeWeight().balanceOf(address(2)), 1);

        hevm.expectRevert(abi.encodeWithSignature("InsufficientUnderlying()"));
        _bHermes.transfer(address(3), 100 ether);
    }

    function testTransferFromFailed() public {
        testDeposit();

        manager.claimWeight(1);

        _bHermes.gaugeWeight().transfer(address(2), 1);

        assertEq(_bHermes.gaugeWeight().balanceOf(address(2)), 1);

        hevm.expectRevert(abi.encodeWithSignature("InsufficientUnderlying()"));
        _bHermes.transferFrom(address(this), address(3), 100 ether);
    }
}
