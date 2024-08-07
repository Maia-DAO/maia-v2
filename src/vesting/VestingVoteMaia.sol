// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {VoteMaia} from "../VoteMaia.sol";

contract VestingVoteMaia is Ownable, ReentrancyGuard, ERC20 {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    /*///////////////////////////////////////////////////////////////
                            VESTING STATE
    ///////////////////////////////////////////////////////////////*/

    VoteMaia public immutable vMaia;
    address private immutable bHermesGauge;
    address private immutable bHermesVote;
    address private immutable vMaiaGovernance;

    constructor(VoteMaia _vMaia, address _owner) ERC20("Vesting VoteMaia", "vVMAIA", 18) {
        _initializeOwner(_owner);
        vMaia = _vMaia;
        bHermesGauge = address(_vMaia.gaugeWeight());
        bHermesVote = address(_vMaia.governance());
        vMaiaGovernance = address(_vMaia.partnerGovernance());

        address(_vMaia.gaugeWeight()).safeApprove(address(_vMaia), type(uint256).max);
        address(_vMaia.governance()).safeApprove(address(_vMaia), type(uint256).max);
        address(_vMaia.partnerGovernance()).safeApprove(address(_vMaia), type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                        CLAIM UTILITY TOKENS LOGIC
    ///////////////////////////////////////////////////////////////*/

    function claim() public nonReentrant {
        vMaia.claimOutstanding();

        bHermesGauge.safeTransferAll(owner());
        bHermesVote.safeTransferAll(owner());
        vMaiaGovernance.safeTransferAll(owner());

        _mint(owner(), vMaia.balanceOf(address(this)) - totalSupply);
    }

    /*///////////////////////////////////////////////////////////////
                       FORFEIT UTILITY TOKENS LOGIC
    ///////////////////////////////////////////////////////////////*/

    // @notice Error thrown when amount is zero
    error AmountIsZero();

    function forfeit(uint256 amount) public nonReentrant {
        if (amount == 0) revert AmountIsZero();

        /// @dev e.g. bHermesRate value 1.1 ether if need to set 1.1X
        uint256 balance = amount.mulWad(vMaia.bHermesRate());

        _burn(msg.sender, amount);

        bHermesGauge.safeTransferFrom(msg.sender, address(this), balance);
        bHermesVote.safeTransferFrom(msg.sender, address(this), balance);
        vMaiaGovernance.safeTransferFrom(msg.sender, address(this), balance);

        vMaia.forfeitMultiple(balance);

        address(vMaia).safeTransfer(msg.sender, amount);
    }
}
