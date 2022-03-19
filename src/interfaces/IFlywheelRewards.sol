// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FlywheelCore} from "../FlywheelCore.sol";

/**
 @title Rewards Module for Flywheel
 @notice The rewards module is a minimal interface for determining the quantity of rewards accrued to a flywheel strategy.

 Different module strategies include:
  * a static reward rate per second
  * a decaying reward rate
  * a dynamic just-in-time reward stream
  * liquid governance reward delegation
 */
interface IFlywheelRewards {
    function getAccruedRewards(ERC20 strategy, uint32 lastUpdatedTimestamp) external returns (uint256 rewards);

    function flywheel() external view returns(FlywheelCore);

    function rewardToken() external view returns(ERC20); 
}
