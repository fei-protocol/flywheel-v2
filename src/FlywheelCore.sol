// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract FlywheelCore {

    /// @dev The token to reward
    ERC20 public immutable rewardToken;

    /// @notice The market index
    mapping(ERC20 => uint256) public marketIndex;

    /// @notice user index per market
    mapping(ERC20 => mapping(address => uint256)) public userIndex;

    /// @notice The COMP accrued but not yet transferred to each user
    mapping(address => uint256) public compAccrued;

    constructor(ERC20 _rewardToken) {
        rewardToken = _rewardToken;
    }

    
}
