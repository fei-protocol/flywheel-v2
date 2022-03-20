// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockBooster} from "./mocks/MockBooster.sol";
import {MockRewards} from "./mocks/MockRewards.sol";

import "../FlywheelCore.sol";

contract FlywheelTest is DSTestPlus {
    FlywheelCore flywheel;
    MockRewards rewards;

    MockERC20 strategy;
    MockERC20 rewardToken;

    address constant user = address(0xDEAD);
    address constant user2 = address(0xBEEF);

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        strategy = new MockERC20("test strategy", "TKN", 18);
        
        flywheel = new FlywheelCore(
            rewardToken, 
            MockRewards(address(0)),
            IFlywheelBooster(address(0)),
            address(this),
            Authority(address(0))
        );

        rewards = new MockRewards(flywheel);

        flywheel.setFlywheelRewards(rewards);
    }

    function testAddStrategy() public {
        flywheel.addStrategyForRewards(strategy);
        (uint224 index, uint32 timestamp) = flywheel.strategyState(strategy);
        require(index == flywheel.ONE());
        require(timestamp == block.timestamp);
    }

    function testFailAddStrategy() public {
        hevm.prank(address(1));
        flywheel.addStrategyForRewards(strategy);
    }

    function testSetFlywheelRewards() public {
        flywheel.setFlywheelRewards(IFlywheelRewards(address(1)));
        require(flywheel.flywheelRewards() == IFlywheelRewards(address(1)));
    }

    function testFailSetFlywheelRewards() public {
        hevm.prank(address(1));
        flywheel.setFlywheelRewards(IFlywheelRewards(address(1)));
    }

    function testAccrue() public {
        strategy.mint(user, 1 ether);
        strategy.mint(user2, 3 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(strategy, 10 ether);

        flywheel.addStrategyForRewards(strategy);
        
        uint256 accrued = flywheel.accrue(strategy, user);

        (uint224 index,) = flywheel.strategyState(strategy);

        require(index == flywheel.ONE() + 2.5 ether);
        require(flywheel.userIndex(strategy, user) == index);
        require(flywheel.rewardsAccrued(user) == 2.5 ether);
        require(accrued == 2.5 ether);
        require(flywheel.rewardsAccrued(user2) == 0 ether);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    }

    function testAccrueTwoUsers() public {
        strategy.mint(user, 1 ether);
        strategy.mint(user2, 3 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(strategy, 10 ether);

        flywheel.addStrategyForRewards(strategy);
        
        (uint256 accrued1, uint256 accrued2) = flywheel.accrue(strategy, user, user2);

        (uint224 index,) = flywheel.strategyState(strategy);

        require(index == flywheel.ONE() + 2.5 ether);
        require(flywheel.userIndex(strategy, user) == index);
        require(flywheel.userIndex(strategy, user2) == index);
        require(flywheel.rewardsAccrued(user) == 2.5 ether);
        require(flywheel.rewardsAccrued(user2) == 7.5 ether);
        require(accrued1 == 2.5 ether);
        require(accrued2 == 7.5 ether);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    }

    function testAccrueBeforeAddStrategy() public {
        strategy.mint(user, 1 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(strategy, 10 ether);

        require(flywheel.accrue(strategy, user) == 0);
    }

    function testAccrueTwoUsersBeforeAddStrategy() public {
        strategy.mint(user, 1 ether);
        strategy.mint(user2, 3 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(strategy, 10 ether);

        (uint256 accrued1, uint256 accrued2) = flywheel.accrue(strategy, user, user2);

        require(accrued1 == 0);
        require(accrued2 == 0);
    }

    function testAccrueTwoUsersSeparately() public {
        strategy.mint(user, 1 ether);
        strategy.mint(user2, 3 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(strategy, 10 ether);

        flywheel.addStrategyForRewards(strategy);
        
        uint256 accrued = flywheel.accrue(strategy, user);

        rewards.setRewardsAmount(strategy, 0);

        uint256 accrued2 = flywheel.accrue(strategy, user2);

        (uint224 index,) = flywheel.strategyState(strategy);

        require(index == flywheel.ONE() + 2.5 ether);
        require(flywheel.userIndex(strategy, user) == index);
        require(flywheel.rewardsAccrued(user) == 2.5 ether);
        require(flywheel.rewardsAccrued(user2) == 7.5 ether);
        require(accrued == 2.5 ether);
        require(accrued2 == 7.5 ether);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    }

    function testAccrueSecondUserLater() public {
        strategy.mint(user, 1 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(strategy, 10 ether);

        flywheel.addStrategyForRewards(strategy);
        
        (uint256 accrued, uint256 accrued2) = flywheel.accrue(strategy, user, user2);

        (uint224 index,) = flywheel.strategyState(strategy);

        require(index == flywheel.ONE() + 10 ether);
        require(flywheel.userIndex(strategy, user) == index);
        require(flywheel.rewardsAccrued(user) == 10 ether);
        require(flywheel.rewardsAccrued(user2) == 0);
        require(accrued == 10 ether);
        require(accrued2 == 0);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    
        strategy.mint(user2, 3 ether);

        rewardToken.mint(address(rewards), 4 ether);
        rewards.setRewardsAmount(strategy, 4 ether);
        
        (accrued, accrued2) = flywheel.accrue(strategy, user, user2);

        (index,) = flywheel.strategyState(strategy);

        require(index == flywheel.ONE() + 11 ether);
        require(flywheel.userIndex(strategy, user) == index);
        require(flywheel.rewardsAccrued(user) == 11 ether);
        require(flywheel.rewardsAccrued(user2) == 3 ether);
        require(accrued == 11 ether);
        require(accrued2 == 3 ether);

        require(rewardToken.balanceOf(address(rewards)) == 14 ether);
    }

    function testClaim() public {
        testAccrue();
        flywheel.claimRewards(user);

        require(rewardToken.balanceOf(address(rewards)) == 7.5 ether);
        require(rewardToken.balanceOf(user) == 2.5 ether);
        require(flywheel.rewardsAccrued(user) == 0);

        flywheel.claimRewards(user);
    }

    function testBoost() public {

        MockBooster booster = new MockBooster();
        booster.setBoost(user, 1 ether);

        flywheel = new FlywheelCore(
            rewardToken, 
            MockRewards(address(0)),
            IFlywheelBooster(address(booster)),
            address(this),
            Authority(address(0))
        );

        rewards = new MockRewards(flywheel);

        flywheel.setFlywheelRewards(rewards);

        strategy.mint(user, 1 ether);
        strategy.mint(user2, 2 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(strategy, 10 ether);

        flywheel.addStrategyForRewards(strategy);
        
        uint256 accrued = flywheel.accrue(strategy, user);

        (uint224 index,) = flywheel.strategyState(strategy);

        require(index == flywheel.ONE() + 2.5 ether);
        require(flywheel.userIndex(strategy, user) == index);
        require(flywheel.rewardsAccrued(user) == 5 ether);
        require(accrued == 5 ether);
        require(flywheel.rewardsAccrued(user2) == 0 ether);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    }
}
