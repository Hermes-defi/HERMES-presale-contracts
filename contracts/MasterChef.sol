// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./NFTChef.sol";
import "./library/DarksideToolBox.sol";
import "./token/DarksideToken.sol";
import "./token/CZDiamondToken.sol";

pragma solidity ^0.8.0;

// MasterChef is the master of Darkside. He can make Darkside and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once DARKSIDE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. .
contract MasterChef is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Burn address
    address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // USDC Polygon (MATIC) address
    address public constant usdcCurrencyAddress =
        0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    // Founder 1 address
    address public constant FOUNDER1_ADDRESS =
        0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31;
    // Founder 2 address
    address public constant FOUNDER2_ADDRESS =
        0x30139dfe2D78aFE7fb539e2F2b765d794fe52cB4;

    uint256 public totalUSDCCollected = 0;

    uint256 public accDepositUSDCRewardPerShare = 0;

    // NFTChef, the keeper of the NFTs!
    NFTChef public nftChef;
    // The CZDIAMOND TOKEN!
    CZDiamondToken public CZDiamond;
    // The DARKSIDE TOKEN!
    DarksideToken public darkside;
    // Darkside's trusty utility belt.
    DarksideToolBox public darksideToolBox;

    uint256 public darksideReleaseGradient;
    uint256 public endDarksideGradientBlock;
    uint256 public endGoalDarksideEmission;
    bool public isIncreasingGradient = false;

    // The amount of time between Rare release rate halvings.
    uint256 public czdReleaseHalfLife;
    // The inital release rate for the rare rewards period.
    uint256 public initialCZDReleaseRate;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 darksideRewardDebt; // Reward debt. See explanation below.
        uint256 CZDiamondRewardDebt; // Reward debt. See explanation below.
        uint256 usdcRewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of DARKSIDEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accDarksidePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accDarksidePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        address lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. DARKSIDEs to distribute per block.
        uint256 lastRewardBlock; // Last block number that DARKSIDEs distribution occurs.
        uint256 accDarksidePerShare; // Accumulated DARKSIDEs per share, times 1e24. See below.
        uint256 accCZDiamondPerShare; // Accumulated CZDIAMONDs per share, times 1e24. See below.
        uint256 depositFeeBPOrNFTMaticFee; // Deposit fee in basis points
        uint256 tokenType; // 0=Token, 1=LP Token, 2=NFT
        uint256 totalLocked; // total units locked in the pool
    }

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when normal DARKSIDE mining starts.
    uint256 public startBlock;

    // The last checked balance of DARKSIDE in the burn waller
    uint256 public lastDarksideBurnBalance = 0;
    // How much of burn do CZDiamond stakers get out of 10000
    uint256 public CZDiamondShareOfBurn = 8197;

    // Darkside referral contract address.
    IDarksideReferral darksideReferral;
    // Referral commission rate in basis points.
    // This is split into 2 halves 3% for the referrer and 3% for the referee.
    uint16 public constant referralCommissionRate = 600;

    // removed to save some space..
    // uint256 public constant CZDiamondPID = 0;

    event AddPool(
        uint256 indexed pid,
        uint256 tokenType,
        uint256 allocPoint,
        address lpToken,
        uint256 depositFeeBPOrNFTMaticFee
    );
    event SetPool(
        uint256 indexed pid,
        uint256 allocPoint,
        uint256 depositFeeBPOrNFTMaticFee
    );
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event GradientUpdated(
        uint256 newEndGoalDarksideEmmission,
        uint256 newEndDarksideEmmissionBlock
    );
    event SetDarksideReferral(address darksideAddress);

    constructor(
        NFTChef _nftChef,
        CZDiamondToken _CZDiamond,
        DarksideToken _darkside,
        DarksideToolBox _darksideToolBox,
        uint256 _startBlock,
        uint256 _czdReleaseHalfLife,
        uint256 _initialCZDReleaseRate,
        uint256 _beginningDarksideEmission,
        uint256 _endDarksideEmission,
        uint256 _gradient1EndBlock
    ) public {
        require(_beginningDarksideEmission < 80 ether, "too high");
        require(_endDarksideEmission < 80 ether, "too high");

        nftChef = _nftChef;
        CZDiamond = _CZDiamond;
        darkside = _darkside;
        darksideToolBox = _darksideToolBox;

        startBlock = _startBlock;

        require(_startBlock < _gradient1EndBlock + 40, "!grad");

        isIncreasingGradient =
            _endDarksideEmission > _beginningDarksideEmission;

        czdReleaseHalfLife = _czdReleaseHalfLife;
        initialCZDReleaseRate = _initialCZDReleaseRate;

        endDarksideGradientBlock = _gradient1EndBlock;
        endGoalDarksideEmission = _endDarksideEmission;

        darksideReleaseGradient = _darksideToolBox.calcEmissionGradient(
            _startBlock,
            _beginningDarksideEmission,
            endDarksideGradientBlock,
            endGoalDarksideEmission
        );

        add(0, 10000, address(_CZDiamond), 0, false);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping(address => bool) public poolExistence;
    modifier nonDuplicated(address _lpToken) {
        require(poolExistence[_lpToken] == false, "dup-pool");
        _;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _tokenType,
        uint256 _allocPoint,
        address _lpToken,
        uint256 _depositFeeBPOrNFTMaticFee,
        bool _withUpdate
    ) public onlyOwner nonDuplicated(_lpToken) {
        require(
            _tokenType == 0 || _tokenType == 1 || _tokenType == 2,
            "!token-type"
        );

        // Make sure the provided token is ERC20/ERC721
        if (_tokenType == 2)
            nftChef.setPoolMaticFee(_lpToken, _depositFeeBPOrNFTMaticFee);
        else {
            ERC20(_lpToken).balanceOf(address(this));
            require(_depositFeeBPOrNFTMaticFee <= 401, "!feeBP");
        }

        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;

        poolExistence[_lpToken] = true;

        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accDarksidePerShare: 0,
                accCZDiamondPerShare: 0,
                depositFeeBPOrNFTMaticFee: _depositFeeBPOrNFTMaticFee,
                tokenType: _tokenType,
                totalLocked: 0
            })
        );

        emit AddPool(
            poolInfo.length - 1,
            _tokenType,
            _allocPoint,
            address(_lpToken),
            _depositFeeBPOrNFTMaticFee
        );
    }

    // Update the given pool's DARKSIDE allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint256 _depositFeeBPOrNFTMaticFee,
        bool _withUpdate
    ) external onlyOwner {
        if (poolInfo[_pid].tokenType == 2)
            nftChef.setPoolMaticFee(
                poolInfo[_pid].lpToken,
                _depositFeeBPOrNFTMaticFee
            );
        else require(_depositFeeBPOrNFTMaticFee <= 401);

        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint =
            (totalAllocPoint - poolInfo[_pid].allocPoint) +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBPOrNFTMaticFee = _depositFeeBPOrNFTMaticFee;
        //poolInfo[_pid].tokenType = _tokenType;
        //poolInfo[_pid].totalLocked = poolInfo[_pid].totalLocked;

        emit SetPool(_pid, _allocPoint, _depositFeeBPOrNFTMaticFee);
    }

    // View function to see pending USDCs on frontend.
    function pendingUSDC(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[0][_user];

        return
            ((user.amount * accDepositUSDCRewardPerShare) / (1e24)) -
            user.usdcRewardDebt;
    }

    // View function to see pending DARKSIDEs on frontend.
    function pendingDarkside(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDarksidePerShare = pool.accDarksidePerShare;

        uint256 lpSupply = pool.totalLocked;
        if (
            block.number > pool.lastRewardBlock &&
            lpSupply != 0 &&
            totalAllocPoint != 0
        ) {
            uint256 release = darksideToolBox.getDarksideRelease(
                isIncreasingGradient,
                darksideReleaseGradient,
                endDarksideGradientBlock,
                endGoalDarksideEmission,
                pool.lastRewardBlock,
                block.number
            );
            uint256 darksideReward = (release * pool.allocPoint) /
                totalAllocPoint;
            accDarksidePerShare =
                accDarksidePerShare +
                ((darksideReward * 1e24) / lpSupply);
        }
        return
            ((user.amount * accDarksidePerShare) / 1e24) -
            user.darksideRewardDebt;
    }

    // View function to see pending CZDiamond on frontend.
    function pendingCZDiamond(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        // CZDiamond pool never gets any more CZDiamond.
        if (_pid == 0) return 0;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCZDiamondPerShare = pool.accCZDiamondPerShare;

        uint256 lpSupply = pool.totalLocked;
        if (
            block.number > pool.lastRewardBlock &&
            lpSupply != 0 &&
            totalAllocPoint > poolInfo[0].allocPoint
        ) {
            uint256 release = darksideToolBox.getCZDiamondRelease(
                initialCZDReleaseRate,
                czdReleaseHalfLife,
                pool.lastRewardBlock,
                block.number
            );
            uint256 CZDiamondReward = (release * pool.allocPoint) /
                (totalAllocPoint - poolInfo[0].allocPoint);
            accCZDiamondPerShare =
                accCZDiamondPerShare +
                ((CZDiamondReward * 1e24) / lpSupply);
        }

        return
            ((user.amount * accCZDiamondPerShare) / 1e24) -
            user.CZDiamondRewardDebt;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
            updatePool(pid);
        }
    }

    // Transfers any excess coins gained through reflection
    // to DARKSIDE and CZDIAMOND
    function skimPool(uint256 poolId) internal {
        PoolInfo storage pool = poolInfo[poolId];
        // cannot skim any tokens we use for staking rewards.
        if (pool.tokenType == 2 || isNativeToken(address(pool.lpToken))) return;

        uint256 trueBalance = ERC20(pool.lpToken).balanceOf(address(this));

        uint256 skim = trueBalance > pool.totalLocked
            ? trueBalance - pool.totalLocked
            : 0;

        if (skim > 1e4) {
            uint256 CZDiamondShare = skim / 2;
            uint256 darksideShare = skim - CZDiamondShare;
            IERC20(pool.lpToken).safeTransfer(
                address(CZDiamond),
                CZDiamondShare
            );
            IERC20(pool.lpToken).safeTransfer(address(darkside), darksideShare);
        }
    }

    // Updates darkside release goal and phase change duration
    function updateDarksideRelease(
        uint256 endBlock,
        uint256 endDarksideEmission
    ) external onlyOwner {
        require(endDarksideEmission < 80 ether, "too high");
        // give some buffer as to stop extrememly large gradients
        require(block.number + 4 < endBlock, "late!");

        // this will be called infrequently
        // and deployed on a cheap gas network POLYGON (MATIC)
        massUpdatePools();

        uint256 currentDarksideEmission = darksideToolBox
            .getDarksideEmissionForBlock(
                block.number,
                isIncreasingGradient,
                darksideReleaseGradient,
                endDarksideGradientBlock,
                endGoalDarksideEmission
            );

        isIncreasingGradient = endDarksideEmission > currentDarksideEmission;
        darksideReleaseGradient = darksideToolBox.calcEmissionGradient(
            block.number,
            currentDarksideEmission,
            endBlock,
            endDarksideEmission
        );

        endDarksideGradientBlock = endBlock;
        endGoalDarksideEmission = endDarksideEmission;

        emit GradientUpdated(endGoalDarksideEmission, endDarksideGradientBlock);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) return;

        uint256 lpSupply = pool.totalLocked;
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        // CZDiamond pool is always pool 0.
        if (poolInfo[0].totalLocked > 0) {
            uint256 usdcRelease = CZDiamond.getUSDCDrip();

            accDepositUSDCRewardPerShare =
                accDepositUSDCRewardPerShare +
                ((usdcRelease * 1e24) / poolInfo[0].totalLocked);
            totalUSDCCollected = totalUSDCCollected + usdcRelease;
        }

        uint256 darksideRelease = darksideToolBox.getDarksideRelease(
            isIncreasingGradient,
            darksideReleaseGradient,
            endDarksideGradientBlock,
            endGoalDarksideEmission,
            pool.lastRewardBlock,
            block.number
        );
        uint256 darksideReward = (darksideRelease * pool.allocPoint) /
            totalAllocPoint;

        // Darkside Txn fees ONLY for CZDiamond stakers.
        if (_pid == 0) {
            uint256 burnBalance = darkside.balanceOf(BURN_ADDRESS);
            darksideReward =
                darksideReward +
                (((burnBalance - lastDarksideBurnBalance) *
                    CZDiamondShareOfBurn) / 10000);

            lastDarksideBurnBalance = burnBalance;
        }

        darkside.mint(address(this), darksideReward);

        if (_pid != 0 && totalAllocPoint > poolInfo[0].allocPoint) {
            uint256 CZDiamondRelease = darksideToolBox.getCZDiamondRelease(
                initialCZDReleaseRate,
                czdReleaseHalfLife,
                pool.lastRewardBlock,
                block.number
            );

            if (CZDiamondRelease > 0) {
                uint256 CZDiamondReward = ((CZDiamondRelease *
                    pool.allocPoint) /
                    (totalAllocPoint - poolInfo[0].allocPoint));

                // Getting CZDiamond allocated specificlly for initial distribution.
                CZDiamondReward = CZDiamond.distribute(
                    address(this),
                    CZDiamondReward
                );

                pool.accCZDiamondPerShare =
                    pool.accCZDiamondPerShare +
                    ((CZDiamondReward * 1e24) / lpSupply);
            }
        }

        pool.accDarksidePerShare =
            pool.accDarksidePerShare +
            ((darksideReward * 1e24) / lpSupply);
        pool.lastRewardBlock = block.number;
    }

    // Return if address is a founder address.
    function isFounder(address addr) public pure returns (bool) {
        return addr == FOUNDER1_ADDRESS || addr == FOUNDER2_ADDRESS;
    }

    // Return if address is a founder address.
    function isNativeToken(address addr) public view returns (bool) {
        return addr == address(CZDiamond) || addr == address(darkside);
    }

    // Deposit LP tokens to MasterChef for DARKSIDE allocation.
    function deposit(
        uint256 _pid,
        uint256 _amountOrId,
        bool isNFTHarvest,
        address _referrer
    ) external payable nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);

        if (
            (pool.tokenType == 2 || _amountOrId > 0) &&
            address(darksideReferral) != address(0) &&
            _referrer != address(0) &&
            _referrer != msg.sender
        ) {
            darksideReferral.recordReferral(msg.sender, _referrer);
        }

        payPendingCZDiamondDarkside(_pid);
        if (_pid == 0) payPendingUSDCReward();

        if (!isNFTHarvest && pool.tokenType == 2) {
            // I don't think we need to verify we recieved the NFT as safeTransferFrom checks this sufficiently.
            nftChef.deposit{value: address(this).balance}(
                pool.lpToken,
                address(msg.sender),
                _amountOrId
            );

            user.amount = user.amount + 1;
            pool.totalLocked = pool.totalLocked + 1;
        } else if (pool.tokenType != 2 && _amountOrId > 0) {
            // Accept the balance of coins we recieve (useful for coins which take fees).
            uint256 previousBalance = ERC20(pool.lpToken).balanceOf(
                address(this)
            );
            IERC20(pool.lpToken).safeTransferFrom(
                address(msg.sender),
                address(this),
                _amountOrId
            );
            _amountOrId =
                ERC20(pool.lpToken).balanceOf(address(this)) -
                previousBalance;
            require(_amountOrId > 0, "0 recieved");

            if (
                pool.depositFeeBPOrNFTMaticFee > 0 &&
                !isNativeToken(address(pool.lpToken))
            ) {
                uint256 depositFee = ((_amountOrId *
                    pool.depositFeeBPOrNFTMaticFee) / 10000);
                // For LPs darkside handles it 100%, destroys and distributes
                uint256 darksideDepositFee = pool.tokenType == 1
                    ? depositFee
                    : (depositFee / 4);
                IERC20(pool.lpToken).safeTransfer(
                    address(darkside),
                    darksideDepositFee
                );
                // darkside handles all LP type tokens
                darkside.swapDepositFeeForETH(
                    address(pool.lpToken),
                    pool.tokenType
                );

                if (pool.tokenType == 0)
                    IERC20(pool.lpToken).safeTransfer(
                        address(CZDiamond),
                        depositFee - darksideDepositFee
                    );

                CZDiamond.convertDepositFeesToUSDC(
                    address(pool.lpToken),
                    pool.tokenType
                );

                user.amount = (user.amount + _amountOrId) - depositFee;
                pool.totalLocked =
                    (pool.totalLocked + _amountOrId) -
                    depositFee;
            } else {
                user.amount = user.amount + _amountOrId;

                pool.totalLocked = pool.totalLocked + _amountOrId;
            }
        }

        user.darksideRewardDebt = ((user.amount * pool.accDarksidePerShare) /
            1e24);
        user.CZDiamondRewardDebt = ((user.amount * pool.accCZDiamondPerShare) /
            1e24);

        if (_pid == 0)
            user.usdcRewardDebt = ((user.amount *
                accDepositUSDCRewardPerShare) / 1e24);

        skimPool(_pid);

        emit Deposit(msg.sender, _pid, _amountOrId);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amountOrId) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(pool.tokenType == 2 || user.amount >= _amountOrId, "!withdraw");

        require(
            !(_pid == 0 && isFounder(msg.sender)) ||
                block.number > startBlock + (60 * 43200),
            "early!"
        );

        updatePool(_pid);

        payPendingCZDiamondDarkside(_pid);
        if (_pid == 0) payPendingUSDCReward();

        uint256 withdrawQuantity = 0;

        if (pool.tokenType == 2) {
            nftChef.withdraw(pool.lpToken, address(msg.sender), _amountOrId);

            withdrawQuantity = 1;
        } else if (_amountOrId > 0) {
            IERC20(pool.lpToken).safeTransfer(address(msg.sender), _amountOrId);

            withdrawQuantity = _amountOrId;
        }

        user.amount = user.amount - withdrawQuantity;
        pool.totalLocked = pool.totalLocked - withdrawQuantity;

        user.darksideRewardDebt = ((user.amount * pool.accDarksidePerShare) /
            1e24);
        user.CZDiamondRewardDebt = ((user.amount * pool.accCZDiamondPerShare) /
            1e24);

        if (_pid == 0)
            user.usdcRewardDebt = ((user.amount *
                accDepositUSDCRewardPerShare) / 1e24);

        skimPool(_pid);

        emit Withdraw(msg.sender, _pid, _amountOrId);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;

        require(
            !(_pid == 0 && isFounder(msg.sender)) ||
                block.number > startBlock + (60 * 43200),
            "early!"
        );

        if (pool.tokenType == 2)
            nftChef.emergencyWithdraw(pool.lpToken, address(msg.sender));
        else IERC20(pool.lpToken).safeTransfer(address(msg.sender), amount);

        user.amount = 0;
        user.darksideRewardDebt = 0;
        user.CZDiamondRewardDebt = 0;
        user.usdcRewardDebt = 0;

        // In the case of an accounting error, we choose to let the user emergency withdraw anyway
        if (pool.totalLocked >= amount)
            pool.totalLocked = pool.totalLocked - amount;
        else pool.totalLocked = 0;

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Pay pending DARKSIDEs & CZDIAMONDs.
    function payPendingCZDiamondDarkside(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 darksidePending = ((user.amount * pool.accDarksidePerShare) /
            1e24) - user.darksideRewardDebt;
        uint256 CZDiamondPending = ((user.amount * pool.accCZDiamondPerShare) /
            1e24) - user.CZDiamondRewardDebt;

        if (darksidePending > 0) {
            // burn founders darkside harvest, without triggering CZD re-mint distro.
            if (isFounder(msg.sender)) safeTokenDarksideBurn(darksidePending);
            else {
                // send rewards
                safeTokenTransfer(
                    address(darkside),
                    msg.sender,
                    darksidePending
                );
                payReferralCommission(msg.sender, darksidePending);
            }
        }
        if (CZDiamondPending > 0) {
            // send rewards
            if (isFounder(msg.sender))
                safeTokenTransfer(
                    address(CZDiamond),
                    BURN_ADDRESS,
                    CZDiamondPending
                );
            else
                safeTokenTransfer(
                    address(CZDiamond),
                    msg.sender,
                    CZDiamondPending
                );
        }
    }

    // Pay pending USDC from the CZDiamond staking reward scheme.
    function payPendingUSDCReward() internal {
        UserInfo storage user = userInfo[0][msg.sender];

        uint256 usdcPending = ((user.amount * accDepositUSDCRewardPerShare) /
            1e24) - user.usdcRewardDebt;

        if (usdcPending > 0) {
            // send rewards
            CZDiamond.transferUSDCToUser(msg.sender, usdcPending);
        }
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough DARKSIDEs.
    function safeTokenDarksideBurn(uint256 _amount) internal {
        uint256 darksideBalance = darkside.balanceOf(address(this));
        if (_amount > darksideBalance) {
            darkside.burn(darksideBalance);
        } else {
            darkside.burn(_amount);
        }
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough DARKSIDEs.
    function safeTokenTransfer(
        address token,
        address _to,
        uint256 _amount
    ) internal {
        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        if (_amount > tokenBal) {
            IERC20(token).safeTransfer(_to, tokenBal);
        } else {
            IERC20(token).safeTransfer(_to, _amount);
        }
    }

    // To receive MATIC from depositers when depositing NFTs
    receive() external payable {}

    // Update the darkside referral contract address by the owner
    function setDarksideReferral(IDarksideReferral _darksideReferral)
        external
        onlyOwner
    {
        require(address(_darksideReferral) != address(0), "!0 address");
        require(address(darksideReferral) == address(0), "!unset");
        darksideReferral = _darksideReferral;

        emit SetDarksideReferral(address(darksideReferral));
    }

    // Pay referral commission to the referrer who referred this user.
    function payReferralCommission(address _user, uint256 _pending) internal {
        if (
            address(darksideReferral) != address(0) &&
            referralCommissionRate > 0
        ) {
            address referrer = darksideReferral.getReferrer(_user);
            uint256 commissionAmount = ((_pending * referralCommissionRate) /
                10000);

            if (referrer != address(0) && commissionAmount > 0) {
                darkside.mint(referrer, commissionAmount / 2);
                darkside.mint(_user, commissionAmount - (commissionAmount / 2));
                darksideReferral.recordReferralCommission(
                    referrer,
                    commissionAmount
                );
            }
        }
    }
}
