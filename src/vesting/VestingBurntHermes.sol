// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {BurntHermes} from "@hermes/BurntHermes.sol";

contract VestingBurntHermes is Ownable, ReentrancyGuard, ERC20 {
    using SafeTransferLib for address;

    /*///////////////////////////////////////////////////////////////
                            VESTING STATE
    ///////////////////////////////////////////////////////////////*/

    BurntHermes public immutable bHermes;
    address private immutable bHermesGauge;
    address private immutable bHermesBoost;
    address private immutable bHermesVote;

    constructor(BurntHermes _bHermes, address _owner) ERC20("Vesting BurntHermes", "vBHERMES", 18) {
        _initializeOwner(_owner);
        bHermes = _bHermes;
        bHermesGauge = address(_bHermes.gaugeWeight());
        bHermesBoost = address(_bHermes.gaugeBoost());
        bHermesVote = address(_bHermes.governance());

        address(_bHermes.gaugeWeight()).safeApprove(address(_bHermes), type(uint256).max);
        address(_bHermes.gaugeBoost()).safeApprove(address(_bHermes), type(uint256).max);
        address(_bHermes.governance()).safeApprove(address(_bHermes), type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                        CLAIM UTILITY TOKENS LOGIC
    ///////////////////////////////////////////////////////////////*/

    function claim() public nonReentrant {
        bHermes.claimOutstanding();

        bHermesGauge.safeTransferAll(owner());
        bHermesBoost.safeTransferAll(owner());
        bHermesVote.safeTransferAll(owner());

        _mint(owner(), bHermes.balanceOf(address(this)) - totalSupply);
    }

    /*///////////////////////////////////////////////////////////////
                       FORFEIT UTILITY TOKENS LOGIC
    ///////////////////////////////////////////////////////////////*/

    // @notice Error thrown when amount is zero
    error AmountIsZero();

    function forfeit(uint256 amount) public nonReentrant {
        if (amount == 0) revert AmountIsZero();

        _burn(msg.sender, amount);

        bHermesGauge.safeTransferFrom(msg.sender, address(this), amount);
        bHermesBoost.safeTransferFrom(msg.sender, address(this), amount);
        bHermesVote.safeTransferFrom(msg.sender, address(this), amount);

        bHermes.forfeitMultiple(amount);

        address(bHermes).safeTransfer(msg.sender, amount);
    }
}
