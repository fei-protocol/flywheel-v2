// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockMarket} from "./mocks/MockMarket.sol";

import "../FlywheelCore.sol";
import {FlywheelDynamicRewards} from "../rewards/FlywheelDynamicRewards.sol";

contract FlywheelTest is DSTestPlus {
    FlywheelCore flywheel;
    FlywheelDynamicRewards rewards;

    MockMarket market;
    MockERC20 rewardToken;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        market = new MockMarket();
        
        flywheel = new FlywheelCore(
            rewardToken, 
            FlywheelDynamicRewards(address(0)),
            IFlywheelBooster(address(0)),
            address(this),
            Authority(address(0))
        );

        rewards = new FlywheelDynamicRewards(rewardToken, address(flywheel));

        flywheel.setFlywheelRewards(rewards);
    }

    function testAddMarket() public {
        flywheel.addMarketForRewards(market);
        (uint224 index, uint32 timestamp) = flywheel.marketState(market);
        require(index == flywheel.ONE());
        require(timestamp == block.timestamp);
    }

    function testSetFlywheelRewards() public {
        flywheel.setFlywheelRewards(IFlywheelRewards(address(1)));
        require(flywheel.flywheelRewards() == IFlywheelRewards(address(1)));
    }
}
