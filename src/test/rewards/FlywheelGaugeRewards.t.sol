// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockERC20Gauges} from "../mocks/MockERC20Gauges.sol";
import {MockRewardsStream} from "../mocks/MockRewardsStream.sol";

import "../../rewards/FlywheelGaugeRewards.sol";

contract FlywheelGaugeRewardsTest is DSTestPlus {

    FlywheelGaugeRewards rewards;

    MockERC20 public rewardToken;

    MockERC20Gauges gaugeToken;

    MockRewardsStream rewardsStream;

    address gauge1 = address(0xDEAD);
    address gauge2 = address(0xBEEF);

    function setUp() public {
        hevm.warp(1000); // skip to cycle 1

        rewardToken = new MockERC20("test token", "TKN", 18);

        rewardsStream = new MockRewardsStream(rewardToken, 100e18);
        rewardToken.mint(address(rewardsStream), 100e25);

        gaugeToken = new MockERC20Gauges(address(this), 1000);
        gaugeToken.setMaxGauges(10);
        gaugeToken.mint(address(this), 100e18);

        rewards = new FlywheelGaugeRewards(FlywheelCore(address(this)), address(this), Authority(address(0)), gaugeToken, IRewardsStream(address(rewardsStream)));
    }

    function testGetRewardsUninitialized() public {
        require(rewards.getAccruedRewards(ERC20(gauge1), 0) == 0);
    }

    function testQueueWithoutGaugesBeforeCycle() public {
        hevm.expectRevert(abi.encodeWithSignature("CycleError()"));
        rewards.queueRewardsForCycle();
    }

    function testQueueWithoutGaugesNoGauges() public {
        hevm.warp(block.timestamp + 1000);
        hevm.expectRevert(abi.encodeWithSignature("EmptyGaugesError()"));
        rewards.queueRewardsForCycle();
    }

    function testQueue() public {
        gaugeToken.addGauge(gauge1);
        gaugeToken.addGauge(gauge2);
        gaugeToken.incrementGauge(gauge1, 1e18);
        gaugeToken.incrementGauge(gauge2, 3e18);

        hevm.warp(block.timestamp + 1000);

        rewards.queueRewardsForCycle();

        (uint112 prior1, uint112 stored1, uint32 cycle1) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior1 == 0);
        require(stored1 == 25e18);
        require(cycle1 == 2000);

        (uint112 prior2, uint112 stored2, uint32 cycle2) = rewards.gaugeQueuedRewards(ERC20(gauge2));
        require(prior2 == 0);
        require(stored2 == 75e18);
        require(cycle2 == 2000);

        require(rewards.gaugeCycle() == 2000);
    }

    function testQueueSkipCycle() public {
        gaugeToken.addGauge(gauge1);
        gaugeToken.incrementGauge(gauge1, 1e18);

        hevm.warp(block.timestamp + 2000);

        rewards.queueRewardsForCycle();

        (uint112 prior, uint112 stored, uint32 cycle) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior == 0);
        require(stored == 100e18);
        require(cycle == 3000);

        require(rewards.gaugeCycle() == 3000);
    }

    function testQueueTwoCycles() public {
        testQueue();
        gaugeToken.decrementGauge(gauge2, 2e18);

        hevm.warp(block.timestamp + 1000);

        rewards.queueRewardsForCycle();

        (uint112 prior1, uint112 stored1, uint32 cycle1) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior1 == 25e18);
        require(stored1 == 50e18);
        require(cycle1 == 3000);

        (uint112 prior2, uint112 stored2, uint32 cycle2) = rewards.gaugeQueuedRewards(ERC20(gauge2));
        require(prior2 == 75e18);
        require(stored2 == 50e18);
        require(cycle2 == 3000);

        require(rewards.gaugeCycle() == 3000);
    }

    function testGetRewards() public {
        testQueue();
        
        require(rewards.getAccruedRewards(ERC20(gauge1), uint32(block.timestamp)) == 0);
        (, uint112 stored, ) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(stored == 25e18);

        // accrue 20% of 25 
        hevm.warp(block.timestamp + 200);
        require(rewards.getAccruedRewards(ERC20(gauge1), uint32(block.timestamp) - 200) == 5e18);
        (, stored, ) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(stored == 20e18);

        // accrue 60% of 25 
        hevm.warp(block.timestamp + 600);
        require(rewards.getAccruedRewards(ERC20(gauge1), uint32(block.timestamp) - 600) == 15e18);
        (, stored, ) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(stored == 5e18);

        // accrue last 20% only after exceeding cycle end
        hevm.warp(block.timestamp + 600);
        require(rewards.getAccruedRewards(ERC20(gauge1), uint32(block.timestamp) - 600) == 5e18);
        (, stored, ) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(stored == 0);

    }
}