
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../../token/ERC20MultiVotes.sol";

contract MockERC20MultiVotes is ERC20MultiVotes {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    constructor(
        address _owner
    ) ERC20("Token", "TKN", 18) Auth(_owner, Authority(address(0))) {}

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }

    function userDelegateSum(address user) public view virtual returns (uint256 sum) {
        for (uint256 i = 0; i < delegateCount(user); i++) {
            sum += delegatesVotesCount(user, _delegates[user].at(i));
        }
    }
}
