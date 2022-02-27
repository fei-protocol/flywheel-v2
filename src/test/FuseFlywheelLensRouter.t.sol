// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {ERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import "../fuse-compatibility/FuseFlywheelCore.sol";
import "../fuse-compatibility/FuseFlywheelLensRouter.sol";

interface Comptroller {
    function admin() external returns (address);

    function _addRewardsDistributor(address distributor) external returns (uint);

    function getRewardsDistributors() external view returns(FlywheelCore[] memory);
}

abstract contract CErc20 is ERC20 {
    function mint(uint256 amount) external virtual returns(uint);
}

contract FlywheelLensRouterIntegration is DSTestPlus {
    FlywheelCore[] flywheels;
    FuseFlywheelLensRouter router;

    // Pool 156 comptroller
    Comptroller comptroller = Comptroller(0x07cd53380FE9B2a5E64099591b498c73F0EfaA66);
    
    // fFRAX-3Crv 
    CErc20 fFRAX3Crv = CErc20(0x2ec70d3Ff3FD7ac5c2a72AAA64A398b6CA7428A5);
    CErc20 fSTETH = CErc20(0xe71b4Cb8A99839042C45CC4cAca31C85C994E79f);

    ERC20 cvx = ERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    ERC20 crv = ERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    ERC20 ldo = ERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32);

    // holder
    address user = 0xB290f2F3FAd4E540D0550985951Cdad2711ac34A;

    function setUp() public {
        flywheels = comptroller.getRewardsDistributors();
        router = new FuseFlywheelLensRouter();
    }

    function testRouter() public {
        bool[] memory accrue = new bool[](3);
        accrue[0] = accrue[1] = accrue[2] = true;
        
        uint rewards0Before = flywheels[0].rewardToken().balanceOf(user);
        uint rewards1Before = flywheels[1].rewardToken().balanceOf(user);
        uint rewards2Before = flywheels[2].rewardToken().balanceOf(user);


        uint[] memory rewards = router.getUnclaimedRewardsForMarket(
            user, 
            CToken(address(fSTETH)), 
            flywheels, 
            accrue, 
            true
        );

        require(flywheels[0].rewardToken().balanceOf(user) - rewards0Before == rewards[0]);
        require(flywheels[1].rewardToken().balanceOf(user) - rewards1Before == rewards[1]);
        require(flywheels[2].rewardToken().balanceOf(user) - rewards2Before == rewards[2]);
    }

    function testRouterMarkets() public {
        CToken[] memory markets = new CToken[](2);
        markets[0] = CToken(address(fSTETH));
        markets[1] = CToken(address(fFRAX3Crv));

        bool[] memory accrue = new bool[](3);
        accrue[0] = accrue[1] = accrue[2] = true;
        
        FlywheelCore[] memory fwheel2 = new FlywheelCore[](2);
        fwheel2[0] = flywheels[0];
        fwheel2[1] = flywheels[1];

        uint rewards0Before = flywheels[0].rewardToken().balanceOf(user);
        uint rewards1Before = flywheels[1].rewardToken().balanceOf(user);

        uint[] memory rewards = router.getUnclaimedRewardsByMarkets(
            user, 
            markets, 
            flywheels, 
            accrue, 
            new bool[](2)
        );

        require(flywheels[0].rewardToken().balanceOf(user) - rewards0Before == rewards[0]);
        require(flywheels[1].rewardToken().balanceOf(user) - rewards1Before == rewards[1]);
    }
}
