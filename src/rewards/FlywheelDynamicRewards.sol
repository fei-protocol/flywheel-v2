// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";
import {IFlywheelRewards} from "../interfaces/IFlywheelRewards.sol";

contract FlywheelDynamicRewards is IFlywheelRewards {
    using SafeTransferLib for ERC20;

    ERC20 public immutable rewardToken;
    address public immutable flywheel;

    constructor(ERC20 _rewardToken, address _flywheel) {
        rewardToken = _rewardToken;
        flywheel = _flywheel;
    }

    function rewardsPerTokenAccrued(ERC20 market, uint32) external override returns (uint256 amount) {
        require(msg.sender == flywheel, "!flywheel");
        rewardToken.safeTransferFrom(address(market), flywheel, amount = rewardToken.balanceOf(address(market)));
    }
}
