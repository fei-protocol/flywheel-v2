// SPDX-License-Identifier: MIT
// Voting logic inspired by OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Votes.sol)

pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";

import {xERC4626, ERC4626} from "./xERC4626.sol";
import {ERC20MultiVotes} from "./ERC20MultiVotes.sol";
import {ERC20Gauges} from "./ERC20Gauges.sol";

interface ITribe {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);

    function getCurrentVotes(address account) external view returns (uint96);
}

contract xTRIBE is ERC20MultiVotes, ERC20Gauges, xERC4626 {

    constructor(address _owner, Authority _authority, uint32 _rewardsCycleLength, ERC20 _tribe) 
        Auth(_owner, _authority) 
        xERC4626(_rewardsCycleLength) 
        ERC4626(_tribe, "xTribe: Gov + Yield", "xTRIBE")
    {}

    function tribe() public view returns (ITribe) {
        return ITribe(address(asset));
    }

    /*///////////////////////////////////////////////////////////////
                             VOTING LOGIC
    //////////////////////////////////////////////////////////////*/

    // TODO convert to assets on both

    function getVotes(address account) public view override returns (uint256) {
        return super.getVotes(account) + tribe().getCurrentVotes(account);
    }

    function getPastVotes(address account, uint256 blockNumber) public view override returns (uint256) {
        return super.getPastVotes(account, blockNumber) + tribe().getPriorVotes(account, blockNumber);
    }

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function _burn(address from, uint256 amount) internal virtual override(ERC20, ERC20Gauges, ERC20MultiVotes) {
        _decrementWeightUntilFree(from, amount);
        _decrementVotesUntilFree(from, amount);
        super._burn(from, amount);
    }

    function transfer(address to, uint256 amount) public virtual override(ERC20, ERC20Gauges, ERC20MultiVotes) returns(bool) {
        _decrementWeightUntilFree(msg.sender, amount);
        _decrementVotesUntilFree(msg.sender, amount);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override(ERC20, ERC20Gauges, ERC20MultiVotes) returns(bool) {
        _decrementWeightUntilFree(from, amount);
        _decrementVotesUntilFree(from, amount);
        return super.transferFrom(from, to, amount);
    }

}