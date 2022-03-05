// SPDX-License-Identifier: MIT
// Voting logic inspired by OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Votes.sol)

pragma solidity ^0.8.0;

import "solmate/mixins/ERC4626.sol";

abstract contract xERC4626 is ERC4626 {

    /// @notice the length of a rewards cycle
    uint32 public immutable rewardsCycleLength;

    /// @notice the end of the current cycle
    uint32 public rewardsCycleEnd;

    uint192 public lastRewardAmount;

    uint256 internal storedTotalAssets;

    constructor(uint32 _rewardsCycleLength) {
        rewardsCycleLength = _rewardsCycleLength;
        // seed initial rewardsCycleEnd
        rewardsCycleEnd = uint32(block.timestamp) / rewardsCycleLength * rewardsCycleLength;
    }

    /// @notice Compute the amount of tokens available to share holders.
    ///         Increases linearly during a reward distribution period.
    function totalAssets() public view override returns (uint256) {
        uint256 storedTotalAssets_ = storedTotalAssets;
        uint256 lastRewardAmount_ = lastRewardAmount;
        uint256 rewardsCycleEnd_ = rewardsCycleEnd;

        if (block.timestamp >= rewardsCycleEnd_) {
            // no rewards or rewards fully unlocked
            // entire balance is available
            return storedTotalAssets_ + lastRewardAmount_;
        } 


        // rewards not fully unlocked
        // add unlocked rewards to stored total
        uint256 unlockedRewards = lastRewardAmount_ * (block.timestamp + rewardsCycleLength - rewardsCycleEnd_) / rewardsCycleLength;
        return storedTotalAssets_ + unlockedRewards;
    }

    function beforeWithdraw(uint256 amount, uint256 shares) internal virtual override {
        storedTotalAssets -= amount;
        super.beforeWithdraw(amount, shares);
    }

    function afterDeposit(uint256 amount, uint256 shares) internal virtual override {
        storedTotalAssets += amount;
        super.afterDeposit(amount, shares);
    }

    /// @notice Distributes rewards to xERC4626 holders
    function syncRewards() external virtual {
        uint192 lastRewardAmount_ = lastRewardAmount;

        require(block.timestamp >= rewardsCycleEnd);

        uint256 storedTotalAssets_ = storedTotalAssets;
        uint192 nextRewards = uint192(asset.balanceOf(address(this)) - storedTotalAssets_ - lastRewardAmount_);

        storedTotalAssets = storedTotalAssets_ + lastRewardAmount_; // SSTORE

        // Combined single SSTORE
        rewardsCycleEnd = (uint32(block.timestamp) + rewardsCycleLength) / rewardsCycleLength * rewardsCycleLength;
        lastRewardAmount = uint192(nextRewards);
    }
}