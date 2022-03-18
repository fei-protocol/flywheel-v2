// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20, ERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockMarket} from "./mocks/MockMarket.sol";
import {MockBooster} from "./mocks/MockBooster.sol";

import "../fuse-compatibility/FuseFlywheelCore.sol";
import {FlywheelDynamicRewardsCycle} from "../rewards/FlywheelDynamicRewardsCycle.sol";

interface Comptroller {
    function admin() external returns (address);

    function _addRewardsDistributor(address distributor) external returns (uint);
}

abstract contract CErc20 is ERC20 {
    function mint(uint256 amount) external virtual returns(uint);
}

contract FlywheelCycleIntegrationTest is DSTestPlus {
    FuseFlywheelCore flywheel;
    FlywheelDynamicRewardsCycle rewards;

    // Pool 156 comptroller
    Comptroller comptroller = Comptroller(0x07cd53380FE9B2a5E64099591b498c73F0EfaA66);
    
    // fUST3POOL
    CErc20 fUST3POOL = CErc20(0xEee0de9187B8B1Ba554E406d0b36a807A00B0ea5);
    
    ERC20 UST3POOL = ERC20(0xEee0de9187B8B1Ba554E406d0b36a807A00B0ea5);

    address ust3poolWhale = 0xCEAF7747579696A2F0bb206a14210e3c9e6fB269;

    address convexWhale = 0x32ad3d7dc190280F5Fd759509DaeB9b06a620ea2;

    // UST3POOL-156 user
    address user = 0xB290f2F3FAd4E540D0550985951Cdad2711ac34A;

    //Convex rewardToken;
    ERC20 rewardToken = ERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);

    struct RewardsCycle {
        uint32 lastSync;
        uint32 rewardsCycleEnd;
        uint192 lastReward;
    }

    function setUp() public {        
        flywheel = new FuseFlywheelCore(
            rewardToken, 
            FlywheelDynamicRewardsCycle(address(0)),
            IFlywheelBooster(address(0)),
            address(this),
            Authority(address(0))
        );

        rewards = new FlywheelDynamicRewardsCycle(rewardToken, address(flywheel), 7 days);

        flywheel.setFlywheelRewards(rewards);
        
        // add fUST3POOL-156 to flywheel and add flywheel to the comptroller
        flywheel.addMarketForRewards(fUST3POOL);
        hevm.prank(comptroller.admin());
        require(comptroller._addRewardsDistributor(address(flywheel)) == 0);

        hevm.prank(address(fUST3POOL));
        rewardToken.approve(address(rewards), type(uint256).max);

        // init accrue 0
        require(flywheel.accrue(fUST3POOL, user) == 0);
        (uint224 index,) = flywheel.marketState(fUST3POOL);
        (uint32 lastSync, uint32 rewardsCycleEnd, uint192 lastReward) = rewards.rewardsCycle(fUST3POOL);

        // transfer initial 100 rewards to cToken
        hevm.prank(convexWhale);
        rewardToken.transfer(address(fUST3POOL), 100e18);
    }

    function testIntegration() public {
        (uint32 lastSync, uint32 rewardsCycleEnd, uint192 lastReward) = rewards.rewardsCycle(fUST3POOL);
        hevm.prank(address(flywheel));
        require(flywheel.accrue(fUST3POOL, user) == 0);
        (uint224 index,) = flywheel.marketState(fUST3POOL);
        require(index == 1e18);

        // finish 1st rewards cycle/start 2nd rewards cycle
        hevm.warp((lastSync + 7 days) / 7 days * 7 days);
        flywheel.accrue(fUST3POOL, user);
        require(rewardToken.balanceOf(address(flywheel)) == 100e18);
        (index,) = flywheel.marketState(fUST3POOL);
        require(index == 1e18);

        // accrue in 2nd cycle
        (lastSync, rewardsCycleEnd, lastReward) = rewards.rewardsCycle(fUST3POOL);
        hevm.warp(lastSync + 1 days);
        flywheel.accrue(fUST3POOL, user);
        (index,) = flywheel.marketState(fUST3POOL);
        uint proportion = 14.2857142857e18 * 1e18 / fUST3POOL.totalSupply() + 1e18;
        require(index / 1e2 == proportion / 1e2);

        hevm.warp(lastSync + 3.5 days);
        flywheel.accrue(fUST3POOL, user);
        (index,) = flywheel.marketState(fUST3POOL);
        proportion = 50e18 * 1e18 / fUST3POOL.totalSupply() + 1e18;
        require(index / 1e2 == proportion / 1e2);

        hevm.warp(lastSync + 7 days);
        flywheel.accrue(fUST3POOL, user);
        (index,) = flywheel.marketState(fUST3POOL);

        // check 7 day rewards cycle distribution of 100 total tokens proportional to user balance 
        proportion = fUST3POOL.balanceOf(user) * 100e18 / fUST3POOL.totalSupply();
        uint userAccrued = flywheel.rewardsAccrued(user);
        require(proportion / 1e4 == userAccrued / 1e4);
    }

    // Gas benchmarks
    function testPreSupplier() public {
        flywheel.flywheelPreSupplierAction(fUST3POOL, user);
    }

    function testPreTransfer() public {
        flywheel.flywheelPreTransferAction(fUST3POOL, user, 0xDB5Ac83c137321Da29a59a7592232bC4ed461730);
    }
}
