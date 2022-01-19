// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {BaseTest, console} from "./base/BaseTest.sol";

import {TestERC20} from "./mocks/TestERC20.sol";
import {ERC20StakingPool} from "../ERC20StakingPool.sol";
import {StakingPoolFactory} from "../StakingPoolFactory.sol";

contract StakingPoolFactoryTest is BaseTest {
    StakingPoolFactory factory;
    TestERC20 rewardToken;
    TestERC20 stakeToken;

    function setUp() public {
        ERC20StakingPool implementation = new ERC20StakingPool();
        factory = new StakingPoolFactory(implementation);

        rewardToken = new TestERC20();
        stakeToken = new TestERC20();
    }

    /// -------------------------------------------------------------------
    /// Gas benchmarking
    /// -------------------------------------------------------------------

    function testGas_createERC20StakingPool(uint64 DURATION) public {
        factory.createERC20StakingPool(rewardToken, stakeToken, DURATION);
    }

    /// -------------------------------------------------------------------
    /// Correctness tests
    /// -------------------------------------------------------------------

    function testCorrectness_createERC20StakingPool(uint64 DURATION) public {
        ERC20StakingPool stakingPool = factory.createERC20StakingPool(
            rewardToken,
            stakeToken,
            DURATION
        );

        assertEq(address(stakingPool.rewardToken()), address(rewardToken));
        assertEq(address(stakingPool.stakeToken()), address(stakeToken));
        assertEq(uint256(stakingPool.DURATION()), uint256(DURATION));
    }
}
