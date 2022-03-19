// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20, ERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockMarket} from "./mocks/MockMarket.sol";
import {MockBooster} from "./mocks/MockBooster.sol";

import "../fuse-compatibility/FuseFlywheelCore.sol";
import {FlywheelStaticRewards} from "../rewards/FlywheelStaticRewards.sol";

interface Comptroller {
    function admin() external returns (address);

    function _addRewardsDistributor(address distributor) external returns (uint);
}

abstract contract CErc20 is ERC20 {
    function mint(uint256 amount) external virtual returns(uint);
}

contract FlywheelIntegrationTest is DSTestPlus {
    FuseFlywheelCore flywheel;
    FlywheelStaticRewards rewards;

    // Pool 8 comptroller
    Comptroller comptroller = Comptroller(0xc54172e34046c1653d1920d40333Dd358c7a1aF4);
    
    // fTRIBE-8
    CErc20 fTRIBE = CErc20(0xFd3300A9a74b3250F1b2AbC12B47611171910b07);
    
    ERC20 tribe = ERC20(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B);

    // fTRIBE-8 whale
    address user = 0x9c5083dd4838E120Dbeac44C052179692Aa5dAC5;

    // tribe treasury
    address core = 0x8d5ED43dCa8C2F7dFB20CF7b53CC7E593635d7b9;

    MockERC20 rewardToken;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);
        
        flywheel = new FuseFlywheelCore(
            rewardToken, 
            FlywheelStaticRewards(address(0)),
            IFlywheelBooster(address(0)),
            address(this),
            Authority(address(0))
        );

        rewards = new FlywheelStaticRewards(flywheel, address(this), Authority(address(0)));

        flywheel.setFlywheelRewards(rewards);
        
        // add fTRIBE-8 to flywheel and add flywheel to the comptroller
        flywheel.addMarketForRewards(fTRIBE);
        hevm.prank(comptroller.admin());
        require(comptroller._addRewardsDistributor(address(flywheel)) == 0);

        // seed rewards to flywheel
        rewardToken.mint(address(rewards), 100 ether);

        // Start reward distribution at 1 token per second
        rewards.setRewardsInfo(fTRIBE, FlywheelStaticRewards.RewardsInfo({rewardsPerSecond: 1 ether, rewardsEndTimestamp: 0}));

        // prime the flywheel storage for accurate gas benchmarking later
        rewardToken.mint(address(flywheel), 1);
        flywheel.flywheelPreSupplierAction(fTRIBE, user);
        flywheel.flywheelPreTransferAction(fTRIBE, user, 0xDB5Ac83c137321Da29a59a7592232bC4ed461730);

        // advance 1 second
        hevm.warp(block.timestamp + 1);
    }

    function testIntegration() public {

        // store expected rewards per token (1 token per second over total supply)
        uint256 rewardsPerToken = (1 ether * 1 ether) / fTRIBE.totalSupply();

        // store expected user rewards (user balance times reward per second over 1 token)
        uint256 userRewards = rewardsPerToken * fTRIBE.balanceOf(user) / 1 ether;
        
        // accrue rewards and check against expected
        require(flywheel.accrue(fTRIBE, user) == userRewards);

        // check market index
        (uint224 index,) = flywheel.marketState(fTRIBE);
        require(index == flywheel.ONE() + rewardsPerToken);

        // claim and check user balance
        flywheel.claimRewards(user);
        require(rewardToken.balanceOf(user) == userRewards);

        // mint more tokens by user and rerun test
        hevm.prank(core);
        tribe.transfer(user, 1e6 ether);

        hevm.startPrank(user);
        tribe.approve(address(fTRIBE), 1e6 ether);
        require(fTRIBE.mint(1e6 ether) == 0);

        // for next test, advance 10 seconds instead of 1 (multiply expectations by 10)
        uint256 rewardsPerToken2 = (10 ether * 1 ether) / fTRIBE.totalSupply();
        hevm.warp(block.timestamp + 10);

        uint256 userRewards2 = rewardsPerToken2 * fTRIBE.balanceOf(user) / 1 ether;
        require(flywheel.accrue(fTRIBE, user) == userRewards2);

        (uint224 index2,) = flywheel.marketState(fTRIBE);

        require(index2 == index + rewardsPerToken2);

        flywheel.claimRewards(user);

        // user balance should accumulate from both rewards
        require(rewardToken.balanceOf(user) == userRewards + userRewards2);

        // the second reward stream should be more than 10x because of additional user mint
        require(userRewards2 > 10 * userRewards);
    }

    // Gas benchmarks
    function testPreSupplier() public {
        flywheel.flywheelPreSupplierAction(fTRIBE, user);
    }

    function testPreTransfer() public {
        flywheel.flywheelPreTransferAction(fTRIBE, user, 0xDB5Ac83c137321Da29a59a7592232bC4ed461730);
    }

    FuseFlywheelCore tribeRewardsDistributor = FuseFlywheelCore(0x73F16f0c0Cd1A078A54894974C5C054D8dC1A3d7);

    function testPreSupplierOld() public {
        tribeRewardsDistributor.flywheelPreSupplierAction(fTRIBE, user);
    }

    function testPreTransferOld() public {
        tribeRewardsDistributor.flywheelPreTransferAction(fTRIBE, user, 0xDB5Ac83c137321Da29a59a7592232bC4ed461730);
    }
}
