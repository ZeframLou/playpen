// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {BaseTest, console} from "./base/BaseTest.sol";

import {xERC20} from "../xERC20.sol";
import {FullMath} from "../lib/FullMath.sol";
import {TestERC20} from "./mocks/TestERC20.sol";
import {ERC20StakingPool} from "../ERC20StakingPool.sol";
import {ERC721StakingPool} from "../ERC721StakingPool.sol";
import {StakingPoolFactory} from "../StakingPoolFactory.sol";

contract xERC20Test is BaseTest {
    uint64 constant DURATION = 7 days;
    address constant tester = address(0x69);
    uint256 constant PRECISION = 1e18;

    StakingPoolFactory factory;
    TestERC20 stakeToken;
    xERC20 stakingPool;

    function setUp() public {
        xERC20 xERC20Implementation = new xERC20();
        ERC20StakingPool erc20StakingPoolImplementation = new ERC20StakingPool();
        ERC721StakingPool erc721StakingPoolImplementation = new ERC721StakingPool();
        factory = new StakingPoolFactory(
            xERC20Implementation,
            erc20StakingPoolImplementation,
            erc721StakingPoolImplementation
        );

        stakeToken = new TestERC20();

        stakingPool = factory.createXERC20(bytes32("Staked SHT"), bytes32("xSHT"), 18, stakeToken, DURATION);
        stakingPool.setRewardDistributor(address(this), true);

        stakeToken.mint(address(this), 1000 ether);
        stakeToken.approve(address(stakingPool), type(uint256).max);

        // do initial staking
        stakingPool.stake(1 ether);

        // do initial reward distribution
        stakingPool.distributeReward(10 ether);
    }

    /// -------------------------------------------------------------------
    /// Gas benchmarking
    /// -------------------------------------------------------------------

    function testGas_stake() public {
        vm.warp(3 days);
        stakingPool.stake(1 ether);
    }

    function testGas_withdraw() public {
        vm.warp(3 days);
        stakingPool.withdraw(0.5 ether);
    }

    /// -------------------------------------------------------------------
    /// Correctness tests
    /// -------------------------------------------------------------------

    function testCorrectness_stake(uint128 amount_, uint56 warpTime) public {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        uint256 amount = amount_;

        // deploy fresh pool
        xERC20 stakingPool_ = factory.createXERC20(bytes32("Staked SHT"), bytes32("xSHT"), 18, stakeToken, DURATION);

        vm.startPrank(tester);

        // warp to future
        vm.warp(warpTime);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        // stake
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool_));
        stakeToken.approve(address(stakingPool_), amount);
        uint256 xERC20Amount = stakingPool_.stake(amount);

        // check balances
        // took stake tokens from tester to staking pool
        assertEqDecimal(stakeToken.balanceOf(tester), 0, 18);
        assertEqDecimal(stakeToken.balanceOf(address(stakingPool_)) - beforeStakingPoolStakeTokenBalance, amount, 18);
        // gave correct share amount
        assertEqDecimal(xERC20Amount, FullMath.mulDiv(amount, PRECISION, stakingPool_.getPricePerFullShare()), 18);
        assertEqDecimal(stakingPool_.balanceOf(tester), xERC20Amount, 18);
    }

    function testCorrectness_withdraw(uint128 amount_, uint56 warpTime, uint56 stakeTime) public {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        vm.assume(stakeTime > 0);
        uint256 amount = amount_;

        // deploy fresh pool
        xERC20 stakingPool_ = factory.createXERC20(bytes32("Staked SHT"), bytes32("xSHT"), 18, stakeToken, DURATION);

        vm.startPrank(tester);

        // warp to future
        vm.warp(warpTime);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        // stake
        uint256 beforeStakingTesterStakeTokenBalance = stakeToken.balanceOf(tester);
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool_));
        stakeToken.approve(address(stakingPool_), amount);
        uint256 xERC20Amount = stakingPool_.stake(amount);

        // warp to simulate staking
        vm.warp(uint256(warpTime) + uint256(stakeTime));

        // withdraw
        stakingPool_.withdraw(xERC20Amount);

        // check balance
        // staking and unstaking didn't change tester stake token balance in aggregate
        assertEqDecimalEpsilonBelow(stakeToken.balanceOf(tester), beforeStakingTesterStakeTokenBalance, 18, 1e36);
        // staking and unstaking didn't change the staking pool's stake token balance in aggregate
        assertLeDecimal(
            stakeToken.balanceOf(address(stakingPool_)) - beforeStakingPoolStakeTokenBalance,
            beforeStakingPoolStakeTokenBalance / 1e18,
            18
        );
        // burnt xERC20 tokens of tester
        assertEqDecimal(stakingPool_.balanceOf(tester), 0, 18);
    }

    function testCorrectness_distributeReward(uint128 amount_, uint56 warpTime, uint8 stakeTimeAsDurationPercentage)
        public
    {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        vm.assume(stakeTimeAsDurationPercentage > 0);

        // deploy fresh pool
        xERC20 stakingPool_ = factory.createXERC20(bytes32("Staked SHT"), bytes32("xSHT"), 18, stakeToken, DURATION);
        stakingPool_.setRewardDistributor(address(this), true);
        stakeToken.approve(address(stakingPool_), type(uint256).max);
        stakingPool_.stake(1 ether);

        uint256 amount = amount_;

        // warp to some time in the future
        vm.warp(warpTime);

        // mint stake token
        stakeToken.mint(address(this), amount);

        // notify new rewards
        uint256 beforeTotalPoolValue =
            FullMath.mulDiv(stakingPool_.getPricePerFullShare(), stakingPool_.totalSupply(), PRECISION);
        stakingPool_.distributeReward(uint128(amount));

        // warp to simulate staking
        uint256 stakeTime = (DURATION * uint256(stakeTimeAsDurationPercentage)) / 100;
        vm.warp(warpTime + stakeTime);

        // check assertions
        uint256 expectedRewardAmount;
        if (stakeTime >= DURATION) {
            // past second reward period, all rewards have been distributed
            expectedRewardAmount = amount;
        } else {
            // during second reward period, rewards are partially distributed
            expectedRewardAmount = (amount * stakeTimeAsDurationPercentage) / 100;
        }
        uint256 rewardAmount = FullMath.mulDiv(
            stakingPool_.getPricePerFullShare(), stakingPool_.totalSupply(), PRECISION
        ) - beforeTotalPoolValue;
        assertEqDecimalEpsilonAround(rewardAmount, expectedRewardAmount, 18, 1);
    }

    function testFail_cannotReinitialize() public {
        stakingPool.initialize(address(this));
    }
}
