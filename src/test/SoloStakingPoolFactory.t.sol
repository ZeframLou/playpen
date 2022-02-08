// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {BaseTest, console} from "./base/BaseTest.sol";

import {TestERC20} from "./mocks/TestERC20.sol";
import {TestERC721} from "./mocks/TestERC721.sol";
import {ERC20StakingPool} from "../ERC20StakingPool.sol";
import {ERC721StakingPool} from "../ERC721StakingPool.sol";
import {SoloStakingPoolFactory} from "../SoloStakingPoolFactory.sol";

contract SoloStakingPoolFactoryTest is BaseTest {
    SoloStakingPoolFactory factory;
    TestERC20 rewardToken;
    TestERC20 stakeToken;
    TestERC721 stakeNFT;

    function setUp() public {
        ERC20StakingPool erc20StakingPoolImplementation = new ERC20StakingPool();
        ERC721StakingPool erc721StakingPoolImplementation = new ERC721StakingPool();
        factory = new SoloStakingPoolFactory(
            erc20StakingPoolImplementation,
            erc721StakingPoolImplementation
        );

        rewardToken = new TestERC20();
        stakeToken = new TestERC20();
        stakeNFT = new TestERC721();
    }

    /// -------------------------------------------------------------------
    /// Gas benchmarking
    /// -------------------------------------------------------------------


    function testGas_createERC20StakingPool(uint64 DURATION) public {
        factory.createERC20StakingPool(rewardToken, stakeToken, DURATION);
    }

    function testGas_createERC721StakingPool(uint64 DURATION) public {
        factory.createERC721StakingPool(rewardToken, stakeNFT, DURATION);
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
        assertEq(stakingPool.DURATION(), DURATION);
    }

    function testCorrectness_createERC721StakingPool(uint64 DURATION) public {
        ERC721StakingPool stakingPool = factory.createERC721StakingPool(
            rewardToken,
            stakeNFT,
            DURATION
        );

        assertEq(address(stakingPool.rewardToken()), address(rewardToken));
        assertEq(address(stakingPool.stakeToken()), address(stakeNFT));
        assertEq(stakingPool.DURATION(), DURATION);
    }
}
