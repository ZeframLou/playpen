// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {BaseTest, console} from "./base/BaseTest.sol";

import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

import {xERC20} from "../xERC20.sol";
import {TestERC20} from "./mocks/TestERC20.sol";
import {TestERC721} from "./mocks/TestERC721.sol";
import {ERC20StakingPool} from "../ERC20StakingPool.sol";
import {ERC721StakingPool} from "../ERC721StakingPool.sol";
import {StakingPoolFactory} from "../StakingPoolFactory.sol";

contract ERC721StakingPoolTest is BaseTest, ERC721TokenReceiver {
    uint64 constant DURATION = 365 days;
    uint256 constant REWARD_AMOUNT = 10 ether;
    uint256 constant INIT_NFT_BALANCE = 266;
    uint256 constant INIT_STAKE_BALANCE = 10;
    address constant tester = address(0x69);

    StakingPoolFactory factory;
    TestERC20 rewardToken;
    TestERC721 stakeToken;
    ERC721StakingPool stakingPool;

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
        stakeToken = new TestERC721();

        stakingPool = factory.createERC721StakingPool(rewardToken, stakeToken, DURATION);

        rewardToken.mint(address(this), 1000 ether);
        for (uint256 i = 0; i < INIT_NFT_BALANCE; i++) {
            stakeToken.safeMint(address(this), i);
        }
        stakeToken.setApprovalForAll(address(stakingPool), true);

        // do initial staking
        uint256[] memory idList = _getIdList(0, INIT_STAKE_BALANCE);
        stakingPool.stake(idList);

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

        uint256[] memory idList = _getIdList(INIT_STAKE_BALANCE, 1);
        stakingPool.stake(idList);
    }

    function testGas_withdraw() public {
        vm.warp(7 days);

        uint256[] memory idList = _getIdList(0, 1);
        stakingPool.withdraw(idList);
    }

    function testGas_getReward() public {
        vm.warp(7 days);
        stakingPool.getReward();
    }

    function testGas_exit() public {
        vm.warp(7 days);

        uint256[] memory idList = _getIdList(0, 1);
        stakingPool.exit(idList);
    }

    /// -------------------------------------------------------------------
    /// Correctness tests
    /// -------------------------------------------------------------------

    function testCorrectness_stake(uint8 amount, uint56 warpTime) public {
        vm.assume(amount > 0);
        vm.assume(warpTime > 0);

        // warp to future
        vm.warp(warpTime);

        // stake
        uint256 beforeThisStakedBalance = stakingPool.balanceOf(address(this));
        uint256 beforeThisStakeTokenBalance = stakeToken.balanceOf(address(this));
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool));
        uint256[] memory idList = _getIdList(INIT_STAKE_BALANCE, amount);
        stakingPool.stake(idList);

        // check balance
        assertEq(beforeThisStakeTokenBalance - stakeToken.balanceOf(address(this)), amount);
        assertEq(stakeToken.balanceOf(address(stakingPool)) - beforeStakingPoolStakeTokenBalance, amount);
        assertEq(stakingPool.balanceOf(address(this)) - beforeThisStakedBalance, amount);
    }

    function testCorrectness_withdraw(uint8 amount, uint56 warpTime, uint56 stakeTime) public {
        vm.assume(amount > 0);
        vm.assume(warpTime > 0);
        vm.assume(stakeTime > 0);

        // warp to future
        vm.warp(warpTime);

        // stake
        uint256[] memory idList = _getIdList(INIT_STAKE_BALANCE, amount);
        stakingPool.stake(idList);

        // warp to simulate staking
        vm.warp(uint256(warpTime) + uint256(stakeTime));

        // withdraw
        uint256 beforeThisStakedBalance = stakingPool.balanceOf(address(this));
        uint256 beforeThisStakeTokenBalance = stakeToken.balanceOf(address(this));
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool));
        stakingPool.withdraw(idList);

        // check balance
        assertEq(stakeToken.balanceOf(address(this)) - beforeThisStakeTokenBalance, amount);
        assertEq(beforeStakingPoolStakeTokenBalance - stakeToken.balanceOf(address(stakingPool)), amount);
        assertEq(beforeThisStakedBalance - stakingPool.balanceOf(address(this)), amount);
    }

    function testCorrectness_getReward(uint8 amount0, uint8 amount1, uint8 stakeTimeAsDurationPercentage) public {
        vm.assume(amount0 > 0);
        vm.assume(amount1 > 0);
        vm.assume(stakeTimeAsDurationPercentage > 0);

        /// -----------------------------------------------------------------------
        /// Stake using address(this)
        /// -----------------------------------------------------------------------

        // start from clean slate
        stakingPool.exit(_getIdList(0, INIT_STAKE_BALANCE));

        // stake
        stakingPool.stake(_getIdList(0, amount0));

        /// -----------------------------------------------------------------------
        /// Stake using tester
        /// -----------------------------------------------------------------------

        vm.startPrank(tester);

        // mint stake tokens
        uint256 startId = INIT_NFT_BALANCE;
        uint256[] memory idList = _getIdList(startId, amount1);
        for (uint256 i = 0; i < amount1; i++) {
            stakeToken.safeMint(tester, idList[i]);
        }

        // stake
        stakeToken.setApprovalForAll(address(stakingPool), true);
        stakingPool.stake(idList);

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
            expectedRewardAmount = (REWARD_AMOUNT * uint256(amount1)) / (uint256(amount0) + uint256(amount1));
        } else {
            // during first reward period, rewards are partially distributed
            expectedRewardAmount = (((REWARD_AMOUNT * stakeTimeAsDurationPercentage) / 100) * uint256(amount1))
                / (uint256(amount0) + uint256(amount1));
        }
        assertEqDecimalEpsilonBelow(rewardAmount, expectedRewardAmount, 18, 1e4);
    }

    function testCorrectness_exit(uint8 amount0, uint8 amount1, uint8 stakeTimeAsDurationPercentage) public {
        vm.assume(amount0 > 0);
        vm.assume(amount1 > 0);
        vm.assume(stakeTimeAsDurationPercentage > 0);

        /// -----------------------------------------------------------------------
        /// Stake using address(this)
        /// -----------------------------------------------------------------------

        // start from clean slate
        stakingPool.exit(_getIdList(0, INIT_STAKE_BALANCE));

        // stake
        stakingPool.stake(_getIdList(0, amount0));

        /// -----------------------------------------------------------------------
        /// Stake using tester
        /// -----------------------------------------------------------------------

        vm.startPrank(tester);

        // mint stake tokens
        uint256 startId = INIT_NFT_BALANCE;
        uint256[] memory idList = _getIdList(startId, amount1);
        for (uint256 i = 0; i < amount1; i++) {
            stakeToken.safeMint(tester, idList[i]);
        }

        // stake
        stakeToken.setApprovalForAll(address(stakingPool), true);
        stakingPool.stake(idList);

        // warp to simulate staking
        uint256 stakeTime = (DURATION * uint256(stakeTimeAsDurationPercentage)) / 100;
        vm.warp(stakeTime);

        // exit
        uint256 beforeStakeTokenBalance = stakeToken.balanceOf(tester);
        uint256 beforeRewardTokenBalance = rewardToken.balanceOf(tester);
        stakingPool.exit(idList);
        uint256 withdrawAmount = stakeToken.balanceOf(tester) - beforeStakeTokenBalance;
        uint256 rewardAmount = rewardToken.balanceOf(tester) - beforeRewardTokenBalance;

        // check assertions
        assertEq(withdrawAmount, amount1);
        uint256 expectedRewardAmount;
        if (stakeTime >= DURATION) {
            // past first reward period, all rewards have been distributed
            expectedRewardAmount = (REWARD_AMOUNT * uint256(amount1)) / (uint256(amount0) + uint256(amount1));
        } else {
            // during first reward period, rewards are partially distributed
            expectedRewardAmount = (((REWARD_AMOUNT * stakeTimeAsDurationPercentage) / 100) * uint256(amount1))
                / (uint256(amount0) + uint256(amount1));
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

    /// -----------------------------------------------------------------------
    /// ERC721 compliance
    /// -----------------------------------------------------------------------

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// -----------------------------------------------------------------------
    /// Utilities
    /// -----------------------------------------------------------------------

    function _getIdList(uint256 startId, uint256 amount) internal pure returns (uint256[] memory idList) {
        idList = new uint256[](amount);
        for (uint256 i = startId; i < startId + amount; i++) {
            idList[i - startId] = i;
        }
    }
}
