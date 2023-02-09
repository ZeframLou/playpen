// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Ownable} from "./lib/Ownable.sol";
import {FullMath} from "./lib/FullMath.sol";
import {ERC20 as CloneERC20} from "./lib/ERC20.sol";
import {Multicall} from "./lib/Multicall.sol";
import {SelfPermit} from "./lib/SelfPermit.sol";

/// @title xERC20
/// @author zefram.eth
/// @notice A special type of ERC20 staking pool where the reward token is the same as
/// the stake token. This enables stakers to receive an xERC20 token representing their
/// stake that can then be transferred or plugged into other things (e.g. Uniswap).
/// @dev xERC20 is inspired by xSUSHI, but is superior because rewards are distributed over time rather
/// than immediately, which prevents MEV bots from stealing the rewards or malicious users staking immediately
/// before the reward distribution and unstaking immediately after.
contract xERC20 is CloneERC20, Ownable, Multicall, SelfPermit {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Error_ZeroOwner();
    error Error_AlreadyInitialized();
    error Error_NotRewardDistributor();
    error Error_ZeroSupply();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event RewardAdded(uint128 reward);
    event Staked(address indexed user, uint256 stakeTokenAmount, uint256 xERC20Amount);
    event Withdrawn(address indexed user, uint256 stakeTokenAmount, uint256 xERC20Amount);

    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    uint256 internal constant PRECISION = 1e18;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    uint64 public currentUnlockEndTimestamp;
    uint64 public lastRewardTimestamp;
    uint128 public lastRewardAmount;

    /// @notice Tracks if an address can call notifyReward()
    mapping(address => bool) public isRewardDistributor;

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @notice The token being staked in the pool
    function stakeToken() public pure returns (ERC20) {
        return ERC20(_getArgAddress(0x41));
    }

    /// @notice The length of each reward period, in seconds
    function DURATION() public pure returns (uint64) {
        return _getArgUint64(0x55);
    }

    /// -----------------------------------------------------------------------
    /// Initialization
    /// -----------------------------------------------------------------------

    /// @notice Initializes the owner, called by StakingPoolFactory
    /// @param initialOwner The initial owner of the contract
    function initialize(address initialOwner) external {
        if (owner() != address(0)) {
            revert Error_AlreadyInitialized();
        }
        if (initialOwner == address(0)) {
            revert Error_ZeroOwner();
        }

        _transferOwnership(initialOwner);
    }

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    /// @notice Stake tokens to receive xERC20 tokens
    /// @param stakeTokenAmount The amount of tokens to stake
    /// @return xERC20Amount The amount of xERC20 tokens minted
    function stake(uint256 stakeTokenAmount) external virtual returns (uint256 xERC20Amount) {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        if (stakeTokenAmount == 0) {
            return 0;
        }

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        xERC20Amount = FullMath.mulDiv(stakeTokenAmount, PRECISION, getPricePerFullShare());
        _mint(msg.sender, xERC20Amount);

        /// -----------------------------------------------------------------------
        /// Effects
        /// -----------------------------------------------------------------------

        stakeToken().safeTransferFrom(msg.sender, address(this), stakeTokenAmount);

        emit Staked(msg.sender, stakeTokenAmount, xERC20Amount);
    }

    /// @notice Withdraw tokens by burning xERC20 tokens
    /// @param xERC20Amount The amount of xERC20 to burn
    /// @return stakeTokenAmount The amount of staked tokens withdrawn
    function withdraw(uint256 xERC20Amount) external virtual returns (uint256 stakeTokenAmount) {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        if (xERC20Amount == 0) {
            return 0;
        }

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------
        stakeTokenAmount = FullMath.mulDiv(xERC20Amount, getPricePerFullShare(), PRECISION);
        _burn(msg.sender, xERC20Amount);

        /// -----------------------------------------------------------------------
        /// Effects
        /// -----------------------------------------------------------------------

        stakeToken().safeTransfer(msg.sender, stakeTokenAmount);

        emit Withdrawn(msg.sender, stakeTokenAmount, xERC20Amount);
    }

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    /// @notice Compute the amount of staked tokens that can be withdrawn by burning
    ///         1 xERC20 token. Increases linearly during a reward distribution period.
    /// @dev Initialized to be PRECISION (representing 1:1)
    /// @return The amount of staked tokens that can be withdrawn by burning
    ///         1 xERC20 token
    function getPricePerFullShare() public view returns (uint256) {
        uint256 totalShares = totalSupply;
        uint256 stakeTokenBalance = stakeToken().balanceOf(address(this));
        if (totalShares == 0 || stakeTokenBalance == 0) {
            return PRECISION;
        }
        uint256 lastRewardAmount_ = lastRewardAmount;
        uint256 currentUnlockEndTimestamp_ = currentUnlockEndTimestamp;
        if (lastRewardAmount_ == 0 || block.timestamp >= currentUnlockEndTimestamp_) {
            // no rewards or rewards fully unlocked
            // entire balance is withdrawable
            return FullMath.mulDiv(stakeTokenBalance, PRECISION, totalShares);
        } else {
            // rewards not fully unlocked
            // deduct locked rewards from balance
            uint256 lastRewardTimestamp_ = lastRewardTimestamp;
            // can't overflow since lockedRewardAmount < lastRewardAmount
            uint256 lockedRewardAmount = (lastRewardAmount_ * (currentUnlockEndTimestamp_ - block.timestamp))
                / (currentUnlockEndTimestamp_ - lastRewardTimestamp_);
            return FullMath.mulDiv(stakeTokenBalance - lockedRewardAmount, PRECISION, totalShares);
        }
    }

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @notice Distributes rewards to xERC20 holders
    /// @dev When not in a distribution period, start a new one with rewardUnlockPeriod seconds.
    ///      When in a distribution period, add rewards to current period.
    function distributeReward(uint128 rewardAmount) external {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        if (totalSupply == 0) {
            revert Error_ZeroSupply();
        }
        if (!isRewardDistributor[msg.sender]) {
            revert Error_NotRewardDistributor();
        }

        /// -----------------------------------------------------------------------
        /// Storage loads
        /// -----------------------------------------------------------------------

        uint256 currentUnlockEndTimestamp_ = currentUnlockEndTimestamp;

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        if (block.timestamp >= currentUnlockEndTimestamp_) {
            // start new reward period
            currentUnlockEndTimestamp = uint64(block.timestamp + DURATION());
            lastRewardAmount = rewardAmount;
        } else {
            // add rewards to current reward period
            // can't overflow since lockedRewardAmount < lastRewardAmount
            uint256 lockedRewardAmount = (lastRewardAmount * (currentUnlockEndTimestamp_ - block.timestamp))
                / (currentUnlockEndTimestamp_ - lastRewardTimestamp);
            // will revert if lastRewardAmount overflows
            lastRewardAmount = uint128(rewardAmount + lockedRewardAmount);
        }
        lastRewardTimestamp = uint64(block.timestamp);

        /// -----------------------------------------------------------------------
        /// Effects
        /// -----------------------------------------------------------------------

        stakeToken().safeTransferFrom(msg.sender, address(this), rewardAmount);

        emit RewardAdded(rewardAmount);
    }

    /// @notice Lets the owner add/remove accounts from the list of reward distributors.
    /// Reward distributors can call notifyRewardAmount()
    /// @param rewardDistributor The account to add/remove
    /// @param isRewardDistributor_ True to add the account, false to remove the account
    function setRewardDistributor(address rewardDistributor, bool isRewardDistributor_) external onlyOwner {
        isRewardDistributor[rewardDistributor] = isRewardDistributor_;
    }
}
