// SPDX-License-Identifier: MIT
// Forked logic from OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Votes.sol)

pragma solidity ^0.8.0;

import "solmate/tokens/ERC20.sol";
import "solmate/utils/SafeCastLib.sol";
import "../../lib/EnumerableSet.sol";

abstract contract ERC20MultiVotes is ERC20 {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCastLib for *;

    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }

    mapping(address => mapping(address => uint256)) private _delegates;

    mapping(address => uint256) public delegatedVotes;

    mapping(address => Checkpoint[]) private _checkpoints;

    mapping(address => EnumerableSet.AddressSet) private _delegateList;

    /**
     * @dev Emitted when a token transfer or delegate change results in changes to an account's voting power.
     */
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    /**
     * @dev Get the `pos`-th checkpoint for `account`.
     */
    function checkpoints(address account, uint32 pos) public view virtual returns (Checkpoint memory) {
        return _checkpoints[account][pos];
    }

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function numCheckpoints(address account) public view virtual returns (uint32) {
        return _checkpoints[account].length.safeCastTo32();
    }

    /**
     * @dev Get the amount of votes currently delegated by `account` to `delegatee`
     */
    function delegates(address account, address delegatee) public view virtual returns (uint256) {
        return _delegates[account][delegatee];
    }

    function freeVotes(address account) public view virtual returns (uint256) {
        return balanceOf[account] - delegatedVotes[account];
    }

    /**
     * @dev Gets the current votes balance for `account`
     */
    function getVotes(address account) public view returns (uint256) {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
    }

    /**
     * @dev Retrieve the number of votes for `account` at the end of `blockNumber`.
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastVotes(address account, uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_checkpoints[account], blockNumber);
    }

    /**
     * @dev Lookup a value in a list of (sorted) checkpoints.
     */
    function _checkpointsLookup(Checkpoint[] storage ckpts, uint256 blockNumber) private view returns (uint256) {
        // We run a binary search to look for the earliest checkpoint taken after `blockNumber`.
        uint256 high = ckpts.length;
        uint256 low = 0;
        while (low < high) {
            uint256 mid = average(low, high);
            if (ckpts[mid].fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : ckpts[high - 1].votes;
    }

    /**
     * @dev Delegate votes from the sender to `delegatee`.
     */
    function delegate(address delegatee, uint256 amount) public virtual {
        _delegate(msg.sender, delegatee, amount);
    }

    /**
     * @dev Delegate votes from the sender to `delegatee`.
     */
    function undelegate(address delegatee, uint256 amount) public virtual {
        _undelegate(msg.sender, delegatee, amount);
    }

    /**
     * @dev Delegate votes from the sender to `delegatee`.
     */
    function redelegate(address oldDelegatee, address newDelegatee, uint256 amount) public virtual {
        _undelegate(msg.sender, oldDelegatee, amount);
        _delegate(msg.sender, newDelegatee, amount);
    }

    /**
     * @dev Change delegation for `delegator` to `delegatee`.
     *
     * Emits events {DelegateChanged} and {DelegateVotesChanged}.
     */
    function _delegate(address delegator, address delegatee, uint256 amount) internal virtual {
        uint256 free = freeVotes(delegator);
        require(free >= amount);

        _delegateList[delegator].add(delegatee); // idempotent add

        _delegates[delegator][delegatee] += amount;
        delegatedVotes[delegator] += amount;

        _writeCheckpoint(delegatee, _add, amount);
    }

    /**
     * @dev Change delegation for `delegator` to `delegatee`.
     *
     * Emits events {DelegateChanged} and {DelegateVotesChanged}.
     */
    function _undelegate(address delegator, address delegatee, uint256 amount) internal virtual {
        uint256 newDelegates = _delegates[delegator][delegatee] - amount;

        if (newDelegates == 0) {
            require(_delegateList[delegator].remove(delegatee)); // fail loud
        }
        
        _delegates[delegator][delegatee] = newDelegates;
        delegatedVotes[delegator] -= amount;

        _writeCheckpoint(delegatee, _subtract, amount);
    }

    function _writeCheckpoint(
        address delegatee,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) private {
        Checkpoint[] storage ckpts = _checkpoints[delegatee];

        uint256 pos = ckpts.length;
        uint256 oldWeight = pos == 0 ? 0 : ckpts[pos - 1].votes;
        uint256 newWeight = op(oldWeight, delta);

        if (pos > 0 && ckpts[pos - 1].fromBlock == block.number) {
            ckpts[pos - 1].votes = newWeight.safeCastTo224();
        } else {
            ckpts.push(Checkpoint({fromBlock: block.number.safeCastTo32(), votes: newWeight.safeCastTo224()}));
        }
        emit DelegateVotesChanged(delegatee, oldWeight, newWeight);
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// NOTE: any "removal" of tokens from a user requires freeVotes(user) < amount.
    /// _decrementUntilFree is called as a greedy algorithm to free up votes.
    /// It may be more gas efficient to free weight before burning or transferring tokens.
    

    function _burn(address from, uint256 amount) internal virtual override {
        _decrementUntilFree(from, amount);
        super._burn(from, amount);
    }

    function transfer(address to, uint256 amount) public virtual override returns(bool) {
        _decrementUntilFree(msg.sender, amount);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns(bool) {
        _decrementUntilFree(from, amount);
        return super.transferFrom(from, to, amount);
    }

    /// a greedy algorithm for freeing votes before a token burn/transfer
    /// frees up entire delegates, so likely will free more than `votes`
    function _decrementUntilFree(address user, uint256 votes) internal {
        uint256 userFreeVotes = freeVotes(user);

        // early return if already free
        if (userFreeVotes >= votes) return;

        // cache total for batch updates
        uint256 totalFreed;

        // Loop through all delegates
        address[] memory delegateList = _delegateList[user].values();

        // Free delegates until through entire list or under weight
        uint256 size = delegateList.length;
        for (uint256 i = 0; i < size && (userFreeVotes + totalFreed) < votes; i++) {
            address delegatee = delegateList[i];
            uint256 delegateVotes = _delegates[user][delegatee];
            if (delegateVotes != 0) {
                totalFreed += delegateVotes;
                
                require(_delegateList[user].remove(delegatee)); // fail loud

                
                _delegates[user][delegatee] = 0;

                _writeCheckpoint(delegatee, _subtract, delegateVotes);
            }
        }

        delegatedVotes[user] -= totalFreed;
    }
}