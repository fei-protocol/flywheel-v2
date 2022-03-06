// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20MultiVotes, ERC20MultiVotes} from "../mocks/MockERC20MultiVotes.sol";

contract ERC20MultiVotesTest is DSTestPlus {

    MockERC20MultiVotes token;
    address constant delegate1 = address(0xDEAD);
    address constant delegate2 = address(0xBEEF);

    function setUp() public {
        token = new MockERC20MultiVotes(address(this));
        token.mint(address(this), 100e18);
        token.setMaxDelegates(2);
    }

    /*///////////////////////////////////////////////////////////////
                        TEST ADMIN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testSetMaxDelegates() public {
        token.setMaxDelegates(5);
        require(token.maxDelegates() == 5);
    }

    function testSetMaxGaugesNonOwner() public {
        hevm.prank(address(1));
        hevm.expectRevert(bytes("UNAUTHORIZED"));
        token.setMaxDelegates(7);
    }

    /*///////////////////////////////////////////////////////////////
                        TEST USER DELEGATION OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice test delegating different delegatees 4 times by multiple users and amounts
    function testDelegate() public {
        // delegate1,user1 +1
        token.delegate(delegate1, 1e18);
        require(token.delegatesVotesCount(address(this), delegate1) == 1e18);
        require(token.userDelegatedVotes(address(this)) == 1e18);
        require(token.getVotes(delegate1) == 1e18);
        require(token.freeVotes(address(this)) == 99e18);

        // delegate2,user1 +2
        token.delegate(delegate2, 2e18);
        require(token.delegatesVotesCount(address(this), delegate2) == 2e18);
        require(token.userDelegatedVotes(address(this)) == 3e18);
        require(token.getVotes(delegate2) == 2e18);
        require(token.freeVotes(address(this)) == 97e18);

        // delegate1,user1 +4
        token.delegate(delegate1, 4e18);
        require(token.delegatesVotesCount(address(this), delegate1) == 5e18);
        require(token.userDelegatedVotes(address(this)) == 7e18);
        require(token.getVotes(delegate1) == 5e18);
        require(token.freeVotes(address(this)) == 93e18);

        // delegate2,user2 +3
        hevm.startPrank(address(1));
        token.mint(address(1), 10e18);

        token.delegate(delegate2, 3e18);
        require(token.delegatesVotesCount(address(1), delegate2) == 3e18);
        require(token.userDelegatedVotes(address(1)) == 3e18);
        require(token.getVotes(delegate2) == 5e18);
        require(token.freeVotes(address(1)) == 7e18);
    }   

    function testDelegateOverVotes() public {
        token.delegate(delegate1, 50e18);
        hevm.expectRevert(abi.encodeWithSignature("DelegationError()"));   
        token.delegate(delegate2, 51e18);
    }

    function testDelegateOverMaxDelegates() public {
        token.delegate(delegate1, 50e18);
        token.delegate(delegate2, 1e18);
        hevm.expectRevert(abi.encodeWithSignature("DelegationError()"));   
        token.delegate(address(this), 1e18);
    }

    /// @notice test undelegate twice, 2 tokens each after delegating by 4.
    function testUndelegate() public {
        token.delegate(delegate1, 4e18);

        token.undelegate(delegate1, 2e18);
        require(token.delegatesVotesCount(address(this), delegate1) == 2e18);
        require(token.userDelegatedVotes(address(this)) == 2e18);
        require(token.getVotes(delegate1) == 2e18);
        require(token.freeVotes(address(this)) == 98e18);

        token.undelegate(delegate1, 2e18);
        require(token.delegatesVotesCount(address(this), delegate1) == 0);
        require(token.userDelegatedVotes(address(this)) == 0);
        require(token.getVotes(delegate1) == 0);
        require(token.freeVotes(address(this)) == 100e18);
    }   

    function testDecrementOverWeight() public {
        token.delegate(delegate1, 50e18);
        hevm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 17));
        token.undelegate(delegate1, 51e18);
    }

    function testRedelegate() public {  
        token.delegate(delegate1, 4e18);

        token.redelegate(delegate1, delegate2, 1e18);
        require(token.delegatesVotesCount(address(this), delegate1) == 3e18);
        require(token.delegatesVotesCount(address(this), delegate2) == 1e18);
        require(token.userDelegatedVotes(address(this)) == 4e18);
        require(token.getVotes(delegate1) == 3e18);
        require(token.getVotes(delegate2) == 1e18);
        require(token.freeVotes(address(this)) == 96e18);
    }

    /*///////////////////////////////////////////////////////////////
                            TEST PAST VOTES
    //////////////////////////////////////////////////////////////*/
    
    function testPastVotes() public {
        token.delegate(delegate1, 4e18);

        uint256 block1 = block.number;
        require(token.numCheckpoints(delegate1) == 1);
        ERC20MultiVotes.Checkpoint memory checkpoint1 = token.checkpoints(delegate1, 0);
        require(checkpoint1.fromBlock == block1);
        require(checkpoint1.votes == 4e18);

        // Same block increase voting power
        token.delegate(delegate1, 4e18);

        require(token.numCheckpoints(delegate1) == 1);
        checkpoint1 = token.checkpoints(delegate1, 0);
        require(checkpoint1.fromBlock == block1);
        require(checkpoint1.votes == 8e18);

        hevm.roll(1);
        uint256 block2 = block.number;
        require(block2 == block1 + 1);

        // Next block decrease voting power
        token.undelegate(delegate1, 2e18);

        require(token.numCheckpoints(delegate1) == 2); // new checkpint
        
        // checkpoint 1 stays same
        checkpoint1 = token.checkpoints(delegate1, 0);
        require(checkpoint1.fromBlock == block1);
        require(checkpoint1.votes == 8e18);

        // new checkpoint 2
        ERC20MultiVotes.Checkpoint memory checkpoint2 = token.checkpoints(delegate1, 1);
        require(checkpoint2.fromBlock == block2);
        require(checkpoint2.votes == 6e18);

        hevm.roll(10);
        uint256 block3 = block.number;
        require(block3 == block2 + 9);

        // 10 blocks later increase voting power
        token.delegate(delegate1, 4e18);

        require(token.numCheckpoints(delegate1) == 3); // new checkpint
        
        // checkpoint 1 stays same
        checkpoint1 = token.checkpoints(delegate1, 0);
        require(checkpoint1.fromBlock == block1);
        require(checkpoint1.votes == 8e18);

        // checkpoint 2 stays same
        checkpoint2 = token.checkpoints(delegate1, 1);
        require(checkpoint2.fromBlock == block2);
        require(checkpoint2.votes == 6e18);

        // new checkpoint 3
        ERC20MultiVotes.Checkpoint memory checkpoint3 = token.checkpoints(delegate1, 2);
        require(checkpoint3.fromBlock == block3);
        require(checkpoint3.votes == 10e18);

        // finally, test getPastVotes between checkpoints
        require(token.getPastVotes(delegate1, block1) == 8e18);
        require(token.getPastVotes(delegate1, block2) == 6e18);
        require(token.getPastVotes(delegate1, block2 + 4) == 6e18);
        require(token.getPastVotes(delegate1, block3 - 1) == 6e18);

        hevm.expectRevert(abi.encodeWithSignature("BlockError()"));
        token.getPastVotes(delegate1, block3); // revert same block
        
        hevm.roll(11);
        require(token.getPastVotes(delegate1, block3) == 10e18);
    }

    /*///////////////////////////////////////////////////////////////
                            TEST ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function testDecrementUntilFreeWhenFree() public {
        token.delegate(delegate1, 10e18);
        token.delegate(delegate2, 20e18);
        require(token.freeVotes(address(this)) == 70e18);

        token.burn(address(this), 50e18);
        require(token.freeVotes(address(this)) == 20e18);

        require(token.delegatesVotesCount(address(this), delegate1) == 10e18);
        require(token.userDelegatedVotes(address(this)) == 30e18);
        require(token.getVotes(delegate1) == 10e18);
        require(token.delegatesVotesCount(address(this), delegate2) == 20e18);
        require(token.getVotes(delegate2) == 20e18);
    }

    function testDecrementUntilFreeSingle() public {
        token.delegate(delegate1, 10e18);
        token.delegate(delegate2, 20e18);
        require(token.freeVotes(address(this)) == 70e18);

        token.transfer(address(1), 80e18);
        require(token.freeVotes(address(this)) == 0);

        require(token.delegatesVotesCount(address(this), delegate1) == 0);
        require(token.userDelegatedVotes(address(this)) == 20e18);
        require(token.getVotes(delegate1) == 0);
        require(token.delegatesVotesCount(address(this), delegate2) == 20e18);
        require(token.getVotes(delegate2) == 20e18);
    }

    function testDecrementUntilFreeDouble() public {
        token.delegate(delegate1, 10e18);
        token.delegate(delegate2, 20e18);
        require(token.freeVotes(address(this)) == 70e18);

        token.approve(address(1), 100e18);
        hevm.prank(address(1));
        token.transferFrom(address(this), address(1), 90e18);

        require(token.freeVotes(address(this)) == 10e18);

        require(token.delegatesVotesCount(address(this), delegate1) == 0);
        require(token.userDelegatedVotes(address(this)) == 0);
        require(token.getVotes(delegate1) == 0);
        require(token.delegatesVotesCount(address(this), delegate2) == 0);
        require(token.getVotes(delegate2) == 0);
    }
}