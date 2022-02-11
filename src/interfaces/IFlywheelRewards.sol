// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

interface IFlywheelRewards {
    function rewardsPerTokenAccrued(ERC20 market, uint32 lastUpdatedTimestamp) external returns (uint256 rewards);
}
