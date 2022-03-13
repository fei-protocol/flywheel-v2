// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockMarket} from "./mocks/MockMarket.sol";
import {MockBooster} from "./mocks/MockBooster.sol";

import "../FlywheelCore.sol";
import {FlywheelDynamicRewards} from "../rewards/FlywheelDynamicRewards.sol";

contract FlywheelTest is DSTestPlus {
    FlywheelCore flywheel;
    FlywheelDynamicRewards rewards;

    MockMarket market;
    MockERC20 rewardToken;

    address constant user = address(0xDEAD);
    address constant user2 = address(0xBEEF);

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

    function testFailAddMarket() public {
        hevm.prank(address(1));
        flywheel.addMarketForRewards(market);
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
        market.mint(user, 1 ether);
        market.mint(user2, 3 ether);

        market.approve(rewardToken, address(rewards));

        rewardToken.mint(address(market), 10 ether);

        flywheel.addMarketForRewards(market);
        
        uint256 accrued = flywheel.accrue(market, user);

        (uint224 index,) = flywheel.marketState(market);

        require(index == flywheel.ONE() + 2.5 ether);
        require(flywheel.userIndex(market, user) == index);
        require(flywheel.rewardsAccrued(user) == 2.5 ether);
        require(accrued == 2.5 ether);
        require(flywheel.rewardsAccrued(user2) == 0 ether);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    }

    function testAccrueTwoUsers() public {
        market.mint(user, 1 ether);
        market.mint(user2, 3 ether);

        market.approve(rewardToken, address(rewards));

        rewardToken.mint(address(market), 10 ether);

        flywheel.addMarketForRewards(market);
        
        (uint256 accrued1, uint256 accrued2) = flywheel.accrue(market, user, user2);

        (uint224 index,) = flywheel.marketState(market);

        require(index == flywheel.ONE() + 2.5 ether);
        require(flywheel.userIndex(market, user) == index);
        require(flywheel.userIndex(market, user2) == index);
        require(flywheel.rewardsAccrued(user) == 2.5 ether);
        require(flywheel.rewardsAccrued(user2) == 7.5 ether);
        require(accrued1 == 2.5 ether);
        require(accrued2 == 7.5 ether);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    }

    function testAccrueBeforeAddMarket() public {
        market.mint(user, 1 ether);

        market.approve(rewardToken, address(rewards));

        rewardToken.mint(address(market), 10 ether);

        require(flywheel.accrue(market, user) == 0);
    }

    function testAccrueTwoUsersBeforeAddMarket() public {
        market.mint(user, 1 ether);
        market.mint(user2, 3 ether);

        market.approve(rewardToken, address(rewards));

        rewardToken.mint(address(market), 10 ether);

        (uint256 accrued1, uint256 accrued2) = flywheel.accrue(market, user, user2);

        require(accrued1 == 0);
        require(accrued2 == 0);
    }

    function testAccrueTwoUsersSeparately() public {
        market.mint(user, 1 ether);
        market.mint(user2, 3 ether);

        market.approve(rewardToken, address(rewards));

        rewardToken.mint(address(market), 10 ether);

        flywheel.addMarketForRewards(market);
        
        uint256 accrued = flywheel.accrue(market, user);
        uint256 accrued2 = flywheel.accrue(market, user2);

        (uint224 index,) = flywheel.marketState(market);

        require(index == flywheel.ONE() + 2.5 ether);
        require(flywheel.userIndex(market, user) == index);
        require(flywheel.rewardsAccrued(user) == 2.5 ether);
        require(flywheel.rewardsAccrued(user2) == 7.5 ether);
        require(accrued == 2.5 ether);
        require(accrued2 == 7.5 ether);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    }

    function testAccrueSecondUserLater() public {
        market.mint(user, 1 ether);

        market.approve(rewardToken, address(rewards));

        rewardToken.mint(address(market), 10 ether);

        flywheel.addMarketForRewards(market);
        
        (uint256 accrued, uint256 accrued2) = flywheel.accrue(market, user, user2);

        (uint224 index,) = flywheel.marketState(market);

        require(index == flywheel.ONE() + 10 ether);
        require(flywheel.userIndex(market, user) == index);
        require(flywheel.rewardsAccrued(user) == 10 ether);
        require(flywheel.rewardsAccrued(user2) == 0);
        require(accrued == 10 ether);
        require(accrued2 == 0);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    
        market.mint(user2, 3 ether);

        rewardToken.mint(address(market), 4 ether);
        
        (accrued, accrued2) = flywheel.accrue(market, user, user2);

        (index,) = flywheel.marketState(market);

        require(index == flywheel.ONE() + 11 ether);
        require(flywheel.userIndex(market, user) == index);
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
            FlywheelDynamicRewards(address(0)),
            IFlywheelBooster(address(booster)),
            address(this),
            Authority(address(0))
        );

        rewards = new FlywheelDynamicRewards(rewardToken, address(flywheel));

        flywheel.setFlywheelRewards(rewards);

        market.mint(user, 1 ether);
        market.mint(user2, 2 ether);

        market.approve(rewardToken, address(rewards));

        rewardToken.mint(address(market), 10 ether);

        flywheel.addMarketForRewards(market);
        
        uint256 accrued = flywheel.accrue(market, user);

        (uint224 index,) = flywheel.marketState(market);

        require(index == flywheel.ONE() + 2.5 ether);
        require(flywheel.userIndex(market, user) == index);
        require(flywheel.rewardsAccrued(user) == 5 ether);
        require(accrued == 5 ether);
        require(flywheel.rewardsAccrued(user2) == 0 ether);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    }
}
