// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Ownable} from "./lib/Ownable.sol";

contract ERC20StakingPool is Ownable {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Error_ZeroAmount();
    error Error_NotRewardDistribution();
    error Error_AmountTooLarge();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    uint64 public lastUpdateTime;
    uint64 public periodFinish;

    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;
    uint256 public totalSupply;

    mapping(address => bool) public isRewardDistribution;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    function rewardToken() public pure returns (ERC20 _rewardToken) {
        uint256 offset = _getImmutableVariablesOffset();
        assembly {
            _rewardToken := shr(0x60, calldataload(offset))
        }
    }

    function stakeToken() public pure returns (ERC20 _stakeToken) {
        uint256 offset = _getImmutableVariablesOffset();
        assembly {
            _stakeToken := shr(0x60, calldataload(add(offset, 0x14)))
        }
    }

    function DURATION() public pure returns (uint64 _DURATION) {
        uint256 offset = _getImmutableVariablesOffset();
        assembly {
            _DURATION := shr(0xc0, calldataload(add(offset, 0x28)))
        }
    }

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    function stake(uint256 amount) external {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        if (amount == 0) {
            revert Error_ZeroAmount();
        }

        /// -----------------------------------------------------------------------
        /// Storage loads
        /// -----------------------------------------------------------------------

        uint256 accountBalance = balanceOf[msg.sender];
        uint64 lastTimeRewardApplicable_ = lastTimeRewardApplicable();
        uint256 totalSupply_ = totalSupply;
        uint256 rewardPerToken_ = _rewardPerToken(
            totalSupply_,
            lastTimeRewardApplicable_,
            rewardRate
        );

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // accrue rewards
        rewardPerTokenStored = rewardPerToken_;
        lastUpdateTime = lastTimeRewardApplicable_;
        rewards[msg.sender] = _earned(
            msg.sender,
            accountBalance,
            rewardPerToken_,
            rewards[msg.sender]
        );
        userRewardPerTokenPaid[msg.sender] = rewardPerToken_;

        // stake
        totalSupply = totalSupply_ + amount;
        balanceOf[msg.sender] = accountBalance + amount;

        /// -----------------------------------------------------------------------
        /// Effects
        /// -----------------------------------------------------------------------

        stakeToken().safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        if (amount == 0) {
            revert Error_ZeroAmount();
        }

        /// -----------------------------------------------------------------------
        /// Storage loads
        /// -----------------------------------------------------------------------

        uint256 accountBalance = balanceOf[msg.sender];
        uint64 lastTimeRewardApplicable_ = lastTimeRewardApplicable();
        uint256 totalSupply_ = totalSupply;
        uint256 rewardPerToken_ = _rewardPerToken(
            totalSupply_,
            lastTimeRewardApplicable_,
            rewardRate
        );

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // accrue rewards
        rewardPerTokenStored = rewardPerToken_;
        lastUpdateTime = lastTimeRewardApplicable_;
        rewards[msg.sender] = _earned(
            msg.sender,
            accountBalance,
            rewardPerToken_,
            rewards[msg.sender]
        );
        userRewardPerTokenPaid[msg.sender] = rewardPerToken_;

        // withdraw stake
        balanceOf[msg.sender] = accountBalance - amount;
        // total supply has 1:1 relationship with staked amounts
        // so can't ever underflow
        unchecked {
            totalSupply = totalSupply_ - amount;
        }

        /// -----------------------------------------------------------------------
        /// Effects
        /// -----------------------------------------------------------------------

        stakeToken().safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        uint256 accountBalance = balanceOf[msg.sender];
        if (accountBalance == 0) {
            revert Error_ZeroAmount();
        }

        /// -----------------------------------------------------------------------
        /// Storage loads
        /// -----------------------------------------------------------------------

        uint64 lastTimeRewardApplicable_ = lastTimeRewardApplicable();
        uint256 totalSupply_ = totalSupply;
        uint256 rewardPerToken_ = _rewardPerToken(
            totalSupply_,
            lastTimeRewardApplicable_,
            rewardRate
        );

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // accrue rewards
        rewardPerTokenStored = rewardPerToken_;
        lastUpdateTime = lastTimeRewardApplicable_;
        userRewardPerTokenPaid[msg.sender] = rewardPerToken_;

        // withdraw stake
        balanceOf[msg.sender] = 0;
        unchecked {
            totalSupply = totalSupply_ - accountBalance;
        }

        // give rewards
        uint256 reward = _earned(
            msg.sender,
            accountBalance,
            rewardPerToken_,
            rewards[msg.sender]
        );
        if (reward > 0) {
            rewards[msg.sender] = 0;
        }

        /// -----------------------------------------------------------------------
        /// Effects
        /// -----------------------------------------------------------------------

        // transfer stake
        stakeToken().safeTransfer(msg.sender, accountBalance);
        emit Withdrawn(msg.sender, accountBalance);

        // transfer rewards
        if (reward > 0) {
            rewardToken().safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function getReward() external {
        /// -----------------------------------------------------------------------
        /// Storage loads
        /// -----------------------------------------------------------------------

        uint256 accountBalance = balanceOf[msg.sender];
        uint64 lastTimeRewardApplicable_ = lastTimeRewardApplicable();
        uint256 totalSupply_ = totalSupply;
        uint256 rewardPerToken_ = _rewardPerToken(
            totalSupply_,
            lastTimeRewardApplicable_,
            rewardRate
        );

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // accrue rewards
        rewardPerTokenStored = rewardPerToken_;
        lastUpdateTime = lastTimeRewardApplicable_;
        userRewardPerTokenPaid[msg.sender] = rewardPerToken_;

        uint256 reward = _earned(
            msg.sender,
            accountBalance,
            rewardPerToken_,
            rewards[msg.sender]
        );
        if (reward > 0) {
            rewards[msg.sender] = 0;

            /// -----------------------------------------------------------------------
            /// Effects
            /// -----------------------------------------------------------------------

            rewardToken().safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    function lastTimeRewardApplicable() public view returns (uint64) {
        return
            block.timestamp < periodFinish
                ? uint64(block.timestamp)
                : periodFinish;
    }

    function rewardPerToken() external view returns (uint256) {
        return
            _rewardPerToken(
                totalSupply,
                lastTimeRewardApplicable(),
                rewardRate
            );
    }

    function earned(address account) external view returns (uint256) {
        return
            _earned(
                account,
                balanceOf[account],
                _rewardPerToken(
                    totalSupply,
                    lastTimeRewardApplicable(),
                    rewardRate
                ),
                rewards[account]
            );
    }

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    function notifyRewardAmount(uint256 reward) external {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        if (reward == 0) {
            revert Error_ZeroAmount();
        }
        if (!isRewardDistribution[msg.sender]) {
            revert Error_NotRewardDistribution();
        }

        /// -----------------------------------------------------------------------
        /// Storage loads
        /// -----------------------------------------------------------------------

        uint256 rewardRate_ = rewardRate;
        uint64 _periodFinish = periodFinish;
        uint64 lastTimeRewardApplicable_ = block.timestamp < _periodFinish
            ? uint64(block.timestamp)
            : _periodFinish;
        uint64 _DURATION = DURATION();

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // accrue rewards
        rewardPerTokenStored = _rewardPerToken(
            totalSupply,
            lastTimeRewardApplicable_,
            rewardRate_
        );
        lastUpdateTime = lastTimeRewardApplicable_;

        // record new reward
        uint256 newRewardRate;
        if (block.timestamp >= _periodFinish) {
            newRewardRate = reward / _DURATION;
        } else {
            uint256 remaining = _periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate_;
            newRewardRate = (reward + leftover) / _DURATION;
        }
        // prevent overflow when computing rewardPerToken
        if (
            newRewardRate >=
            (type(uint256).max / FixedPointMathLib.WAD) / _DURATION
        ) {
            revert Error_AmountTooLarge();
        }
        rewardRate = newRewardRate;
        lastUpdateTime = uint64(block.timestamp);
        periodFinish = uint64(block.timestamp + _DURATION);

        emit RewardAdded(reward);
    }

    function setRewardDistribution(
        address _rewardDistribution,
        bool _isRewardDistribution
    ) external onlyOwner {
        isRewardDistribution[_rewardDistribution] = _isRewardDistribution;
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    function _earned(
        address account,
        uint256 accountBalance,
        uint256 rewardPerToken_,
        uint256 accountRewards
    ) internal view returns (uint256) {
        return
            accountBalance.fmul(
                rewardPerToken_ - userRewardPerTokenPaid[account],
                FixedPointMathLib.WAD
            ) + accountRewards;
    }

    function _rewardPerToken(
        uint256 totalSupply_,
        uint256 lastTimeRewardApplicable_,
        uint256 rewardRate_
    ) internal view returns (uint256) {
        if (totalSupply_ == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable_ - lastUpdateTime) * rewardRate_).fdiv(
                totalSupply_,
                FixedPointMathLib.WAD
            );
    }

    function _getImmutableVariablesOffset()
        internal
        pure
        returns (uint256 offset)
    {
        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
    }
}
