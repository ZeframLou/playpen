// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {BaseTest, console} from "./base/BaseTest.sol";

import {xERC20} from "../xERC20.sol";
import {TestERC20} from "./mocks/TestERC20.sol";
import {ERC20StakingPool} from "../ERC20StakingPool.sol";
import {ERC721StakingPool} from "../ERC721StakingPool.sol";
import {StakingPoolFactory} from "../StakingPoolFactory.sol";

contract ERC20StakingPoolTest is BaseTest {
    uint64 constant DURATION = 365 days;
    uint256 constant REWARD_AMOUNT = 10 ether;
    address constant tester = address(0x69);

    StakingPoolFactory factory;
    TestERC20 rewardToken;
    TestERC20 stakeToken;
    ERC20StakingPool stakingPool;

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

        stakingPool = factory.createERC20StakingPool(rewardToken, stakeToken, DURATION);

        rewardToken.mint(address(this), 1000 ether);
        stakeToken.mint(address(this), 1000 ether);
        stakeToken.approve(address(stakingPool), type(uint256).max);

        // do initial staking
        stakingPool.stake(1 ether);

        // distribute rewards
        rewardToken.transfer(address(stakingPool), REWARD_AMOUNT);
        stakingPool.setRewardDistributor(address(this), true);
        stakingPool.notifyRewardAmount(REWARD_AMOUNT);
    }

    /// -------------------------------------------------------------------
    /// Gas benchmarking
    /// -------------------------------------------------------------------

    function testGas_stake() public {
        vm.warp(7 days);
        stakingPool.stake(1 ether);
    }

    function testGas_withdraw() public {
        vm.warp(7 days);
        stakingPool.withdraw(0.5 ether);
    }

    function testGas_getReward() public {
        vm.warp(7 days);
        stakingPool.getReward();
    }

    function testGas_exit() public {
        vm.warp(7 days);
        stakingPool.exit();
    }

    /// -------------------------------------------------------------------
    /// Correctness tests
    /// -------------------------------------------------------------------

    function testCorrectness_stake(uint128 amount_, uint56 warpTime) public {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        uint256 amount = amount_;

        vm.startPrank(tester);

        // warp to future
        vm.warp(warpTime);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        // stake
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool));
        stakeToken.approve(address(stakingPool), amount);
        stakingPool.stake(amount);

        // check balance
        assertEqDecimal(stakeToken.balanceOf(tester), 0, 18);
        assertEqDecimal(stakeToken.balanceOf(address(stakingPool)) - beforeStakingPoolStakeTokenBalance, amount, 18);
        assertEqDecimal(stakingPool.balanceOf(tester), amount, 18);
    }

    function testCorrectness_withdraw(uint128 amount_, uint56 warpTime, uint56 stakeTime) public {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        uint256 amount = amount_;

        vm.startPrank(tester);

        // warp to future
        vm.warp(warpTime);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        // stake
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool));
        stakeToken.approve(address(stakingPool), amount);
        stakingPool.stake(amount);

        // warp to simulate staking
        vm.warp(uint256(warpTime) + uint256(stakeTime));

        // withdraw
        stakingPool.withdraw(amount);

        // check balance
        assertEqDecimal(stakeToken.balanceOf(tester), amount, 18);
        assertEqDecimal(stakeToken.balanceOf(address(stakingPool)) - beforeStakingPoolStakeTokenBalance, 0, 18);
        assertEqDecimal(stakingPool.balanceOf(tester), 0, 18);
    }

    function testCorrectness_getReward(uint128 amount0_, uint128 amount1_, uint8 stakeTimeAsDurationPercentage)
        public
    {
        vm.assume(amount0_ > 0);
        vm.assume(amount1_ > 0);
        vm.assume(stakeTimeAsDurationPercentage > 0);
        uint256 amount0 = amount0_;
        uint256 amount1 = amount1_;

        /// -----------------------------------------------------------------------
        /// Stake using address(this)
        /// -----------------------------------------------------------------------

        // start from clean slate
        stakingPool.exit();

        // mint stake tokens
        stakeToken.mint(address(this), amount0);

        // stake
        stakingPool.stake(amount0);

        /// -----------------------------------------------------------------------
        /// Stake using tester
        /// -----------------------------------------------------------------------

        vm.startPrank(tester);

        // mint stake tokens
        stakeToken.mint(tester, amount1);

        // stake
        stakeToken.approve(address(stakingPool), amount1);
        stakingPool.stake(amount1);

        // warp to simulate staking
        uint256 stakeTime = (DURATION * uint256(stakeTimeAsDurationPercentage)) / 100;
        vm.warp(stakeTime);

        // get reward
        uint256 beforeBalance = rewardToken.balanceOf(tester);
        stakingPool.getReward();
        uint256 rewardAmount = rewardToken.balanceOf(tester) - beforeBalance;

        // check assertions
        uint256 expectedRewardAmount;
        if (stakeTime >= DURATION) {
            // past first reward period, all rewards have been distributed
            expectedRewardAmount = (REWARD_AMOUNT * amount1) / (amount0 + amount1);
        } else {
            // during first reward period, rewards are partially distributed
            expectedRewardAmount =
                (((REWARD_AMOUNT * stakeTimeAsDurationPercentage) / 100) * amount1) / (amount0 + amount1);
        }
        assertEqDecimalEpsilonBelow(rewardAmount, expectedRewardAmount, 18, 1e4);
    }

    function testCorrectness_exit(uint128 amount0_, uint128 amount1_, uint8 stakeTimeAsDurationPercentage) public {
        vm.assume(amount0_ > 0);
        vm.assume(amount1_ > 0);
        vm.assume(stakeTimeAsDurationPercentage > 0);
        uint256 amount0 = amount0_;
        uint256 amount1 = amount1_;

        /// -----------------------------------------------------------------------
        /// Stake using address(this)
        /// -----------------------------------------------------------------------

        // start from clean slate
        stakingPool.exit();

        // mint stake tokens
        stakeToken.mint(address(this), amount0);

        // stake
        stakingPool.stake(amount0);

        /// -----------------------------------------------------------------------
        /// Stake using tester
        /// -----------------------------------------------------------------------

        vm.startPrank(tester);

        // mint stake tokens
        stakeToken.mint(tester, amount1);

        // stake
        stakeToken.approve(address(stakingPool), amount1);
        stakingPool.stake(amount1);

        // warp to simulate staking
        uint256 stakeTime = (DURATION * uint256(stakeTimeAsDurationPercentage)) / 100;
        vm.warp(stakeTime);

        // exit
        uint256 beforeStakeTokenBalance = stakeToken.balanceOf(tester);
        uint256 beforeRewardTokenBalance = rewardToken.balanceOf(tester);
        stakingPool.exit();
        uint256 withdrawAmount = stakeToken.balanceOf(tester) - beforeStakeTokenBalance;
        uint256 rewardAmount = rewardToken.balanceOf(tester) - beforeRewardTokenBalance;

        // check assertions
        assertEqDecimal(withdrawAmount, amount1, 18);
        uint256 expectedRewardAmount;
        if (stakeTime >= DURATION) {
            expectedRewardAmount = (REWARD_AMOUNT * amount1) / (amount0 + amount1);
        } else {
            expectedRewardAmount =
                (((REWARD_AMOUNT * stakeTimeAsDurationPercentage) / 100) * amount1) / (amount0 + amount1);
        }
        assertEqDecimalEpsilonBelow(rewardAmount, expectedRewardAmount, 18, 1e4);
    }

    function testCorrectness_notifyRewardAmount(uint128 amount_, uint56 warpTime, uint8 stakeTimeAsDurationPercentage)
        public
    {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        vm.assume(stakeTimeAsDurationPercentage > 0);
        uint256 amount = amount_;

        // warp to some time in the future
        vm.warp(warpTime);

        // get earned reward amount from existing rewards
        uint256 beforeBalance = rewardToken.balanceOf(address(this));
        stakingPool.getReward();
        uint256 rewardAmount = rewardToken.balanceOf(address(this)) - beforeBalance;

        // compute expected earned rewards
        uint256 expectedRewardAmount;
        if (warpTime >= DURATION) {
            // past first reward period, all rewards have been distributed
            expectedRewardAmount = REWARD_AMOUNT;
        } else {
            // during first reward period, rewards are partially distributed
            expectedRewardAmount = (REWARD_AMOUNT * warpTime) / DURATION;
        }
        uint256 leftoverRewardAmount = REWARD_AMOUNT - expectedRewardAmount;

        // mint reward tokens
        rewardToken.mint(address(stakingPool), amount);

        // notify new rewards
        stakingPool.notifyRewardAmount(amount);

        // warp to simulate staking
        uint256 stakeTime = (DURATION * uint256(stakeTimeAsDurationPercentage)) / 100;
        vm.warp(warpTime + stakeTime);

        // get reward
        beforeBalance = rewardToken.balanceOf(address(this));
        stakingPool.getReward();
        rewardAmount += rewardToken.balanceOf(address(this)) - beforeBalance;

        // check assertions
        if (stakeTime >= DURATION) {
            // past second reward period, all rewards have been distributed
            expectedRewardAmount += leftoverRewardAmount + amount;
        } else {
            // during second reward period, rewards are partially distributed
            expectedRewardAmount += ((leftoverRewardAmount + amount) * stakeTimeAsDurationPercentage) / 100;
        }
        assertEqDecimalEpsilonBelow(rewardAmount, expectedRewardAmount, 18, 1e4);
    }

    function testFail_cannotReinitialize() public {
        stakingPool.initialize(address(this));
    }
}
