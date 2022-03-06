// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockMarket} from "./mocks/MockMarket.sol";

import {FlywheelStaticRewards, Authority} from "../rewards/FlywheelStaticRewards.sol";

contract FlywheelStaticRewardsTest is DSTestPlus {

    FlywheelStaticRewards rewards;

    MockMarket market;
    MockERC20 rewardToken;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        market = new MockMarket();

        rewards = new FlywheelStaticRewards(rewardToken, address(this), address(this), Authority(address(0)));
    }

    function testSetRewardsInfo() public {
        (uint224 rewardsPerSecond, uint32 rewardsEndTimestamp) = rewards.rewardsInfo(market);
        require(rewardsPerSecond == 0);
        require(rewardsEndTimestamp == 0);

        uint32 newEnd = uint32(block.timestamp) + 100;
        rewards.setRewardsInfo(market, FlywheelStaticRewards.RewardsInfo({rewardsPerSecond: 1 ether, rewardsEndTimestamp: newEnd}));

        (rewardsPerSecond, rewardsEndTimestamp) = rewards.rewardsInfo(market);

        require(rewardsPerSecond == 1 ether);
        require(rewardsEndTimestamp == newEnd);
    }

    function testGetAccruedRewards() public {
        hevm.warp(1000);
        testSetRewardsInfo();

        rewardToken.mint(address(rewards), 100 ether);

        require(rewards.getAccruedRewards(market, uint32(block.timestamp - 10)) == 10 ether);
        require(rewardToken.balanceOf(address(rewards)) == 100 ether);
    }

    function testGetAccruedRewardsAfterEnd() public {
        hevm.warp(1000);
        testSetRewardsInfo();
        hevm.warp(2000);

        rewardToken.mint(address(rewards), 100 ether);

        require(rewards.getAccruedRewards(market, uint32(block.timestamp - 1000)) == 100 ether);
        require(rewardToken.balanceOf(address(rewards)) == 100 ether);
    }

    function testGetAccruedRewardsCappedAfterEnd() public {
        hevm.warp(1000);
        testSetRewardsInfo();
        hevm.warp(2000);

        rewardToken.mint(address(rewards), 20 ether);

        require(rewards.getAccruedRewards(market, uint32(block.timestamp - 1000)) == 100 ether);
        require(rewardToken.balanceOf(address(rewards)) == 20 ether);
    }
}