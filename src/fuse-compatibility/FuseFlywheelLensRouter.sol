    
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {FlywheelCore, ERC20} from "../FlywheelCore.sol";

abstract contract CToken is ERC20 {
    function plugin() external view virtual returns(Plugin);
}

interface Plugin {
    function claimRewards() external;
}

contract FuseFlywheelLensRouter {
    function getUnclaimedRewardsForMarket(address user, CToken market, FlywheelCore[] calldata flywheels, bool[] calldata accrue, bool claimPlugin) external returns(uint256[] memory rewards) {
        uint size = flywheels.length;
        rewards = new uint[](size);

        if (claimPlugin) {
            market.plugin().claimRewards();
        }

        for (uint256 i = 0; i < size; i++) {
            if (accrue[i]) {
                rewards[i] = flywheels[i].accrue(market, user);
            } else {
                rewards[i] = flywheels[i].rewardsAccrued(user);
            }

            flywheels[i].claimRewards(user);
        }
    }

    function getUnclaimedRewardsByMarkets(address user, CToken[] calldata markets, FlywheelCore[] calldata flywheels, bool[] calldata accrue, bool[] calldata claimPlugins) external returns(uint256[] memory rewards) {
        rewards = new uint[](flywheels.length);

        for (uint256 i = 0; i < flywheels.length; i++) {
            for (uint256 j = 0; j < markets.length; j++) {
                CToken market = markets[j];
                if (claimPlugins[j]) {
                    market.plugin().claimRewards();
                }

                // Overwrite, because rewards are cumulative
                if (accrue[i]) {
                    rewards[i] = flywheels[i].accrue(market, user);
                } else {
                    rewards[i] = flywheels[i].rewardsAccrued(user);
                } 
            }

            flywheels[i].claimRewards(user);
        }
    }
}
