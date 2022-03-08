    
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {FlywheelCore, ERC20} from "../FlywheelCore.sol";

abstract contract CToken is ERC20 {
    function plugin() external view virtual returns(Plugin);

    function exchangeRateCurrent() external virtual returns(uint256);

    function PRECISION() external view virtual returns(uint256);
}

interface PriceOracle {
    function getUnderlyingPrice(CToken cToken) external view returns (uint);

    function price(address underlying) external view returns (uint);
}

interface Comptroller {
    function getRewardsDistributors() external view returns (FlywheelCore[] memory);

    function getAllMarkets() external view returns(CToken[] memory);

    function oracle() external view returns(PriceOracle);

    function admin() external returns (address);

    function _addRewardsDistributor(address distributor) external returns (uint);
}

interface Plugin {
    function claimRewards() external;
}

contract FuseFlywheelLensRouter {

    struct MarketRewardsInfo {
        /// @dev comptroller oracle price of market underlying
        uint256 underlyingPrice;
        CToken market;
        RewardsInfo[] rewardsInfo;
    }

    struct RewardsInfo {
        /// @dev rewards in `rewardToken` paid per underlying staked token in `market` per second
        uint256 rewardSpeedPerSecondPerToken;

        /// @dev comptroller oracle price of reward token
        uint256 rewardTokenPrice;

        /// @dev APR scaled by 1e18. Calculated as rewardSpeedPerSecondPerToken * rewardTokenPrice * 365.25 days / underlyingPrice * market.PRECISION() / market.exchangeRateCurrent()
        uint256 formattedAPR;

        address flywheel;
        address rewardToken;
    }

    function getMarketRewardsInfo(Comptroller comptroller) external returns(MarketRewardsInfo[] memory) {
        CToken[] memory markets = comptroller.getAllMarkets();
        FlywheelCore[] memory flywheels = comptroller.getRewardsDistributors();
        address[] memory rewardTokens = new address[](flywheels.length);
        uint256[] memory rewardTokenPrices = new uint256[](flywheels.length);
        PriceOracle oracle = comptroller.oracle();

        MarketRewardsInfo[] memory infoList = new MarketRewardsInfo[](markets.length);
        for (uint256 i = 0; i < markets.length; i++) {
            RewardsInfo[] memory rewardsInfo = new RewardsInfo[](flywheels.length);

            CToken market = markets[i];
            uint256 price = oracle.getUnderlyingPrice(market);

            try market.plugin() returns(Plugin plugin) {
                try plugin.claimRewards() {} catch {}
            } catch {}

            for (uint256 j = 0; j < flywheels.length; j++) {
                FlywheelCore flywheel = flywheels[j];
                if (i == 0) {
                    address rewardToken = address(flywheel.rewardToken());
                    rewardTokens[j] = rewardToken;
                    rewardTokenPrices[j] = oracle.price(rewardToken);
                }
                uint256 rewardSpeedPerSecondPerToken;
                {

                    (uint224 indexBefore, uint32 lastUpdatedTimestampBefore) = flywheel.marketState(market);
                    flywheel.accrue(market, address(0));
                    (uint224 indexAfter, uint32 lastUpdatedTimestampAfter) = flywheel.marketState(market);
                    if (lastUpdatedTimestampAfter > lastUpdatedTimestampBefore) {
                        rewardSpeedPerSecondPerToken = (indexAfter - indexBefore) / (lastUpdatedTimestampAfter - lastUpdatedTimestampBefore);
                    }
                }  
                rewardsInfo[j] = RewardsInfo({
                    rewardSpeedPerSecondPerToken: rewardSpeedPerSecondPerToken,
                    rewardTokenPrice: rewardTokenPrices[j],
                    formattedAPR: rewardSpeedPerSecondPerToken * rewardTokenPrices[j] * 365.25 days / price * 1e18 / market.exchangeRateCurrent(),
                    flywheel: address(flywheel),
                    rewardToken: rewardTokens[j]
                });
            }

            infoList[i] = MarketRewardsInfo({
                market: market,
                rewardsInfo: rewardsInfo,
                underlyingPrice: price 
            });
        }

        return infoList;
    }

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
