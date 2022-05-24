// SPDX-License-Identifier: MIT
// Voting logic inspired by OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Votes.sol)

pragma solidity ^0.8.0;

import "solmate/tokens/ERC20.sol";
import "../utils/MultiVotes.sol";
import "../../lib/EnumerableSet.sol";
import "../interfaces/Errors.sol";

/**
 @title ERC20 Multi-Delegation Voting contract
 @notice an ERC20 extension which allows delegations to multiple delegatees up to a user's balance on a given block.
 */
abstract contract ERC20MultiVotes is ERC20, MultiVotes {
    /*///////////////////////////////////////////////////////////////
                        VOTE CALCULATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function freeVotes(address account) public view virtual override returns (uint256) {
        return balanceOf[account] - userDelegatedVotes[account];
    }

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// NOTE: any "removal" of tokens from a user requires freeVotes(user) < amount.
    /// _decrementVotesUntilFree is called as a greedy algorithm to free up votes.
    /// It may be more gas efficient to free weight before burning or transferring tokens.

    function _burn(address from, uint256 amount) internal virtual override {
        _decrementVotesUntilFree(from, amount);
        super._burn(from, amount);
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _decrementVotesUntilFree(msg.sender, amount);
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        _decrementVotesUntilFree(from, amount);
        return super.transferFrom(from, to, amount);
    }

    /*///////////////////////////////////////////////////////////////
                             EIP-712 LOGIC
    //////////////////////////////////////////////////////////////*/

    function DOMAIN_SEPARATOR() public view virtual override(ERC20, MultiVotes) returns (bytes32) {
        return super.DOMAIN_SEPARATOR();
    }
}
