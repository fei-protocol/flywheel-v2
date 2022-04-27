// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockERC4626} from "solmate/test/utils/mocks/MockERC4626.sol";
import {FlywheelCore, IFlywheelBooster, IFlywheelRewards} from "../../FlywheelCore.sol";
import {MockBooster} from "../mocks/MockBooster.sol";
import {MockRewards} from "../mocks/MockRewards.sol";

import {FlywheelProportionalRewards, Authority} from "../../rewards/FlywheelProportionalRewards.sol";

contract FlywheelProportionalRewardsTest is DSTestPlus {
    FlywheelProportionalRewards rewards;

    MockERC20 strategy;
    MockERC20 public rewardToken;
    MockERC4626 public vault;
    FlywheelCore public flywheel;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        strategy = new MockERC20("test strategy", "TKN", 18);

        vault = new MockERC4626(rewardToken, "TestFeiSavingsRate", "TFSR");

        flywheel = new FlywheelCore(
            rewardToken,
            MockRewards(address(0)),
            IFlywheelBooster(address(0)),
            address(this),
            Authority(address(0))
        );

        rewards = new FlywheelProportionalRewards(FlywheelCore(address(this)), address(this), Authority(address(0)));
    }

    function setRewardsInfo() public {
        (, uint224 rewardsBasisPointsPerYear, uint32 rewardsEndTimestamp) = rewards.rewardsInfo(strategy);
        require(rewardsBasisPointsPerYear == 0);
        require(rewardsEndTimestamp == 0);

        rewards.setRewardsInfo(
            strategy,
            FlywheelProportionalRewards.RewardsInfo({
                vault: address(vault),
                rewardBasisPointsPerYear: 10_000,
                rewardsEndTimestamp: 0
            })
        );
    }

    function testGetAccruedRewards() public {
        setRewardsInfo();

        address alice = address(0xABCD);
        rewardToken.mint(alice, 100 ether);
        hevm.prank(alice);
        rewardToken.approve(address(vault), 100 ether);
        hevm.prank(alice);
        vault.deposit(100 ether, alice);

        flywheel.accrue(strategy, alice);

        hevm.warp(365.25 days); // 1 year in seconds;

        flywheel.accrue(strategy, alice);

        // After exactly one year at 100% APR, we should have exactly our starting balance in rewards!
        assertEq(rewards.getAccruedRewards(strategy, uint32(block.timestamp - 365.25 days)), 100 ether);
    }
}
