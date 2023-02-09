// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {BaseTest, console} from "./base/BaseTest.sol";

import {xERC20} from "../xERC20.sol";
import {TestERC20} from "./mocks/TestERC20.sol";
import {TestERC721} from "./mocks/TestERC721.sol";
import {ERC20StakingPool} from "../ERC20StakingPool.sol";
import {ERC721StakingPool} from "../ERC721StakingPool.sol";
import {StakingPoolFactory} from "../StakingPoolFactory.sol";

contract StakingPoolFactoryTest is BaseTest {
    StakingPoolFactory factory;
    TestERC20 rewardToken;
    TestERC20 stakeToken;
    TestERC721 stakeNFT;

    function setUp() public {
        xERC20 xERC20Implementation = new xERC20();
        ERC20StakingPool erc20StakingPoolImplementation = new ERC20StakingPool();
        ERC721StakingPool erc721StakingPoolImplementation = new ERC721StakingPool();
        factory = new StakingPoolFactory(
            xERC20Implementation,
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

    function testGas_createXERC20(bytes32 name, bytes32 symbol, uint8 decimals, uint64 DURATION) public {
        factory.createXERC20(name, symbol, decimals, stakeToken, DURATION);
    }

    function testGas_createERC20StakingPool(uint64 DURATION) public {
        factory.createERC20StakingPool(rewardToken, stakeToken, DURATION);
    }

    function testGas_createERC721StakingPool(uint64 DURATION) public {
        factory.createERC721StakingPool(rewardToken, stakeNFT, DURATION);
    }

    /// -------------------------------------------------------------------
    /// Correctness tests
    /// -------------------------------------------------------------------

    function testCorrectness_createXERC20(bytes32 name, bytes32 symbol, uint8 decimals, uint64 DURATION) public {
        xERC20 stakingPool = factory.createXERC20(name, symbol, decimals, stakeToken, DURATION);

        assertEq(stakingPool.name(), string(abi.encodePacked(name)));
        assertEq(stakingPool.symbol(), string(abi.encodePacked(symbol)));
        assertEq(stakingPool.decimals(), decimals);
        assertEq(address(stakingPool.stakeToken()), address(stakeToken));
        assertEq(uint256(stakingPool.DURATION()), uint256(DURATION));
    }

    function testCorrectness_createERC20StakingPool(uint64 DURATION) public {
        ERC20StakingPool stakingPool = factory.createERC20StakingPool(rewardToken, stakeToken, DURATION);

        assertEq(address(stakingPool.rewardToken()), address(rewardToken));
        assertEq(address(stakingPool.stakeToken()), address(stakeToken));
        assertEq(stakingPool.DURATION(), DURATION);
    }

    function testCorrectness_createERC721StakingPool(uint64 DURATION) public {
        ERC721StakingPool stakingPool = factory.createERC721StakingPool(rewardToken, stakeNFT, DURATION);

        assertEq(address(stakingPool.rewardToken()), address(rewardToken));
        assertEq(address(stakingPool.stakeToken()), address(stakeNFT));
        assertEq(stakingPool.DURATION(), DURATION);
    }
}
