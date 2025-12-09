// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Comprehensive DeFi Protocol
 * @notice Platform DeFi lengkap dengan DEX, Liquidity Pools, Yield Farming, Flash Loans, dan Governance
 * @dev Sistem kompleks dengan multiple komponen yang terintegrasi
 */

// =====================================================
// INTERFACES
// =====================================================

interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
    function getPriceETH(address token) external view returns (uint256);
}

interface IFlashLoanReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

// =====================================================
// LIQUIDITY POOL TOKEN (LP Token)
// =====================================================

contract LPToken is ERC20 {
    address public immutable pool;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        pool = msg.sender;
    }

    modifier onlyPool() {
        require(msg.sender == pool, "Only pool can mint/burn");
        _;
    }

    function mint(address to, uint256 amount) external onlyPool {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyPool {
        _burn(from, amount);
    }
}

// =====================================================
// AMM DEX - AUTOMATED MARKET MAKER
// =====================================================

contract AMMDEX is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        uint256 kLast; // k value at last liquidity event
        uint256 fee; // Fee in basis points (100 = 1%)
        LPToken lpToken;
        bool exists;
    }

    mapping(address => mapping(address => Pool)) public pools;
    mapping(address => address[]) public tokenPairs;
    
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public protocolFee = 30; // 0.3% default fee
    address public feeRecipient;
    IPriceOracle public oracle;

    event PoolCreated(address indexed token0, address indexed token1, address indexed pool);
    event LiquidityAdded(address indexed provider, address token0, address token1, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, address token0, address token1, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address indexed to);

    constructor(address _feeRecipient, address _oracle) {
        feeRecipient = _feeRecipient;
        oracle = IPriceOracle(_oracle);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Create new liquidity pool
     */
    function createPool(address token0, address token1, uint256 fee) external returns (address) {
        require(token0 != token1, "Same token");
        require(token0 < token1, "Invalid order");
        require(!pools[token0][token1].exists, "Pool exists");
        require(fee > 0 && fee <= 1000, "Invalid fee"); // Max 10%

        string memory name = string(abi.encodePacked("LP-", _symbol(token0), "-", _symbol(token1)));
        string memory symbol = string(abi.encodePacked("LP-", _symbol(token0), "-", _symbol(token1)));
        
        LPToken lpToken = new LPToken(name, symbol);
        
        pools[token0][token1] = Pool({
            token0: token0,
            token1: token1,
            reserve0: 0,
            reserve1: 0,
            totalSupply: 0,
            kLast: 0,
            fee: fee,
            lpToken: lpToken,
            exists: true
        });

        tokenPairs[token0].push(token1);
        
        emit PoolCreated(token0, token1, address(lpToken));
        return address(lpToken);
    }

    /**
     * @notice Add liquidity to pool
     */
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external nonReentrant whenNotPaused returns (uint256 liquidity) {
        require(token0 < token1, "Invalid order");
        Pool storage pool = pools[token0][token1];
        require(pool.exists, "Pool not exists");

        uint256 amount0;
        uint256 amount1;

        if (pool.reserve0 == 0 && pool.reserve1 == 0) {
            // First liquidity provision
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            uint256 amount1Optimal = _quote(amount0Desired, pool.reserve0, pool.reserve1);
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Insufficient amount1");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = _quote(amount1Desired, pool.reserve1, pool.reserve0);
                require(amount0Optimal >= amount0Min, "Insufficient amount0");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        uint256 _totalSupply = pool.totalSupply;
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - 1000; // Lock first 1000 wei
        } else {
            liquidity = Math.min(
                amount0 * _totalSupply / pool.reserve0,
                amount1 * _totalSupply / pool.reserve1
            );
        }

        require(liquidity > 0, "Insufficient liquidity");

        pool.reserve0 = pool.reserve0 + amount0;
        pool.reserve1 = pool.reserve1 + amount1;
        pool.totalSupply = _totalSupply + liquidity;
        pool.kLast = pool.reserve0 * pool.reserve1;

        pool.lpToken.mint(to, liquidity);

        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    /**
     * @notice Remove liquidity from pool
     */
    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        require(token0 < token1, "Invalid order");
        Pool storage pool = pools[token0][token1];
        require(pool.exists, "Pool not exists");

        pool.lpToken.burn(msg.sender, liquidity);

        uint256 _totalSupply = pool.totalSupply;
        amount0 = liquidity * pool.reserve0 / _totalSupply;
        amount1 = liquidity * pool.reserve1 / _totalSupply;

        require(amount0 >= amount0Min && amount1 >= amount1Min, "Insufficient amounts");

        pool.reserve0 = pool.reserve0 - amount0;
        pool.reserve1 = pool.reserve1 - amount1;
        pool.totalSupply = _totalSupply - liquidity;
        pool.kLast = pool.reserve0 * pool.reserve1;

        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);

        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    /**
     * @notice Swap tokens
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(tokenIn != tokenOut, "Same token");
        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;
        
        Pool storage pool = pools[token0][token1];
        require(pool.exists, "Pool not exists");

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 reserveIn = tokenIn == token0 ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = tokenIn == token0 ? pool.reserve1 : pool.reserve0;

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - pool.fee);
        amountOut = amountInWithFee * reserveOut / (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        require(amountOut >= amountOutMin, "Insufficient output");

        if (tokenIn == token0) {
            pool.reserve0 = pool.reserve0 + amountIn;
            pool.reserve1 = pool.reserve1 - amountOut;
        } else {
            pool.reserve1 = pool.reserve1 + amountIn;
            pool.reserve0 = pool.reserve0 - amountOut;
        }

        IERC20(tokenOut).safeTransfer(to, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, to);
    }

    /**
     * @notice Get amount out for swap
     */
    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) external view returns (uint256) {
        require(tokenIn != tokenOut, "Same token");
        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;
        
        Pool memory pool = pools[token0][token1];
        if (!pool.exists) return 0;

        uint256 reserveIn = tokenIn == token0 ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = tokenIn == token0 ? pool.reserve1 : pool.reserve0;

        if (reserveIn == 0 || reserveOut == 0) return 0;

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - pool.fee);
        return amountInWithFee * reserveOut / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
    }

    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256) {
        require(amountA > 0, "Insufficient amount");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");
        return amountA * reserveB / reserveA;
    }

    function _symbol(address token) internal view returns (string memory) {
        try ERC20(token).symbol() returns (string memory s) {
            return s;
        } catch {
            return "TOKEN";
        }
    }

    // Admin functions
    function setProtocolFee(uint256 _fee) external onlyRole(ADMIN_ROLE) {
        require(_fee <= 1000, "Fee too high");
        protocolFee = _fee;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}

// =====================================================
// YIELD FARMING PROTOCOL
// =====================================================

contract YieldFarm is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Farm {
        address lpToken;
        address rewardToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
        uint256 totalStaked;
        bool active;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    IERC20 public immutable rewardToken;
    uint256 public rewardPerBlock;
    uint256 public totalAllocPoint;
    uint256 public startBlock;
    uint256 public bonusEndBlock;
    uint256 public constant BONUS_MULTIPLIER = 2;

    mapping(address => Farm) public farms;
    mapping(address => mapping(address => UserInfo)) public userInfo;
    address[] public farmList;

    AMMDEX public immutable dex;

    event FarmAdded(address indexed lpToken, address indexed rewardToken, uint256 allocPoint);
    event Deposit(address indexed user, address indexed lpToken, uint256 amount);
    event Withdraw(address indexed user, address indexed lpToken, uint256 amount);
    event Harvest(address indexed user, address indexed lpToken, uint256 amount);

    constructor(
        address _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        address _dex
    ) {
        rewardToken = IERC20(_rewardToken);
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;
        dex = AMMDEX(_dex);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Add new farm
     */
    function addFarm(
        address lpToken,
        address rewardToken,
        uint256 allocPoint,
        bool withUpdate
    ) external onlyRole(ADMIN_ROLE) {
        if (withUpdate) {
            massUpdateFarms();
        }

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        
        farms[lpToken] = Farm({
            lpToken: lpToken,
            rewardToken: rewardToken,
            allocPoint: allocPoint,
            lastRewardBlock: lastRewardBlock,
            accRewardPerShare: 0,
            totalStaked: 0,
            active: true
        });

        totalAllocPoint = totalAllocPoint + allocPoint;
        farmList.push(lpToken);

        emit FarmAdded(lpToken, rewardToken, allocPoint);
    }

    /**
     * @notice Deposit LP tokens to farm
     */
    function deposit(address lpToken, uint256 amount) external nonReentrant whenNotPaused {
        Farm storage farm = farms[lpToken];
        require(farm.active, "Farm not active");

        updateFarm(lpToken);

        UserInfo storage user = userInfo[msg.sender][lpToken];

        if (user.amount > 0) {
            uint256 pending = user.amount * farm.accRewardPerShare / 1e12 - user.rewardDebt;
            if (pending > 0) {
                user.pendingRewards = user.pendingRewards + pending;
            }
        }

        if (amount > 0) {
            IERC20(lpToken).safeTransferFrom(msg.sender, address(this), amount);
            user.amount = user.amount + amount;
            farm.totalStaked = farm.totalStaked + amount;
        }

        user.rewardDebt = user.amount * farm.accRewardPerShare / 1e12;

        emit Deposit(msg.sender, lpToken, amount);
    }

    /**
     * @notice Withdraw LP tokens from farm
     */
    function withdraw(address lpToken, uint256 amount) external nonReentrant {
        Farm storage farm = farms[lpToken];
        UserInfo storage user = userInfo[msg.sender][lpToken];

        require(user.amount >= amount, "Insufficient balance");

        updateFarm(lpToken);

        uint256 pending = user.amount * farm.accRewardPerShare / 1e12 - user.rewardDebt;
        if (pending > 0) {
            user.pendingRewards = user.pendingRewards + pending;
        }

        if (amount > 0) {
            user.amount = user.amount - amount;
            farm.totalStaked = farm.totalStaked - amount;
            IERC20(lpToken).safeTransfer(msg.sender, amount);
        }

        user.rewardDebt = user.amount * farm.accRewardPerShare / 1e12;

        emit Withdraw(msg.sender, lpToken, amount);
    }

    /**
     * @notice Harvest rewards
     */
    function harvest(address lpToken) external nonReentrant {
        Farm storage farm = farms[lpToken];
        UserInfo storage user = userInfo[msg.sender][lpToken];

        updateFarm(lpToken);

        uint256 pending = user.amount * farm.accRewardPerShare / 1e12 - user.rewardDebt;
        if (pending > 0 || user.pendingRewards > 0) {
            user.pendingRewards = user.pendingRewards + pending;
            uint256 totalRewards = user.pendingRewards;
            user.pendingRewards = 0;
            user.rewardDebt = user.amount * farm.accRewardPerShare / 1e12;

            if (farm.rewardToken != address(0)) {
                IERC20(farm.rewardToken).safeTransfer(msg.sender, totalRewards);
            } else {
                rewardToken.safeTransfer(msg.sender, totalRewards);
            }

            emit Harvest(msg.sender, lpToken, totalRewards);
        }
    }

    /**
     * @notice Update farm reward variables
     */
    function updateFarm(address lpToken) public {
        Farm storage farm = farms[lpToken];
        if (block.number <= farm.lastRewardBlock) {
            return;
        }

        if (farm.totalStaked == 0) {
            farm.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(farm.lastRewardBlock, block.number);
        uint256 reward = multiplier * rewardPerBlock * farm.allocPoint / totalAllocPoint;

        if (farm.rewardToken != address(0)) {
            // Use custom reward token, need to mint/transfer
        } else {
            // Use default reward token
        }

        farm.accRewardPerShare = farm.accRewardPerShare + (reward * 1e12 / farm.totalStaked);
        farm.lastRewardBlock = block.number;
    }

    /**
     * @notice Update all farms
     */
    function massUpdateFarms() public {
        for (uint256 i = 0; i < farmList.length; i++) {
            updateFarm(farmList[i]);
        }
    }

    /**
     * @notice Get multiplier for bonus period
     */
    function getMultiplier(uint256 from, uint256 to) public view returns (uint256) {
        if (to <= bonusEndBlock) {
            return (to - from) * BONUS_MULTIPLIER;
        } else if (from >= bonusEndBlock) {
            return to - from;
        } else {
            return (bonusEndBlock - from) * BONUS_MULTIPLIER + (to - bonusEndBlock);
        }
    }

    /**
     * @notice Get pending rewards
     */
    function pendingRewards(address lpToken, address user) external view returns (uint256) {
        Farm memory farm = farms[lpToken];
        UserInfo memory userData = userInfo[user][lpToken];

        if (block.number > farm.lastRewardBlock && farm.totalStaked != 0) {
            uint256 multiplier = getMultiplier(farm.lastRewardBlock, block.number);
            uint256 reward = multiplier * rewardPerBlock * farm.allocPoint / totalAllocPoint;
            uint256 accRewardPerShare = farm.accRewardPerShare + (reward * 1e12 / farm.totalStaked);
            return userData.amount * accRewardPerShare / 1e12 - userData.rewardDebt + userData.pendingRewards;
        } else {
            return userData.amount * farm.accRewardPerShare / 1e12 - userData.rewardDebt + userData.pendingRewards;
        }
    }
}

// =====================================================
// FLASH LOAN FACILITY
// =====================================================

contract FlashLoanProvider is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant FLASH_LOAN_FEE = 9; // 0.09%
    uint256 public constant FEE_DENOMINATOR = 10000;

    mapping(address => uint256) public reserves;

    event FlashLoan(address indexed asset, uint256 amount, address indexed receiver);

    function flashLoan(
        address asset,
        uint256 amount,
        address receiverAddress,
        bytes calldata params
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(receiverAddress != address(0), "Invalid receiver");

        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");

        IERC20(asset).safeTransfer(receiverAddress, amount);

        require(
            IFlashLoanReceiver(receiverAddress).executeOperation(
                _asSingletonArray(asset),
                _asSingletonArray(amount),
                _asSingletonArray(_calculateFee(amount)),
                msg.sender,
                params
            ),
            "Flash loan execution failed"
        );

        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));
        uint256 repaid = balanceAfter - balanceBefore;
        uint256 fee = _calculateFee(amount);
        require(repaid >= amount + fee, "Insufficient repayment");

        reserves[asset] = reserves[asset] + fee;

        emit FlashLoan(asset, amount, receiverAddress);
    }

    function deposit(address asset, uint256 amount) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        reserves[asset] = reserves[asset] + amount;
    }

    function withdraw(address asset, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(reserves[asset] >= amount, "Insufficient reserves");
        reserves[asset] = reserves[asset] - amount;
        IERC20(asset).safeTransfer(msg.sender, amount);
    }

    function _calculateFee(uint256 amount) internal pure returns (uint256) {
        return amount * FLASH_LOAN_FEE / FEE_DENOMINATOR;
    }

    function _asSingletonArray(address element) private pure returns (address[] memory array) {
        array = new address[](1);
        array[0] = element;
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory array) {
        array = new uint256[](1);
        array[0] = element;
    }
}

// =====================================================
// GOVERNANCE PROTOCOL
// =====================================================

contract Governance is AccessControl {

    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    struct Proposal {
        uint256 id;
        address proposer;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
    }

    IERC20 public immutable votingToken;
    uint256 public proposalThreshold;
    uint256 public votingPeriod;
    uint256 public quorumVotes;
    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 votes
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    constructor(
        address _votingToken,
        uint256 _proposalThreshold,
        uint256 _votingPeriod,
        uint256 _quorumVotes
    ) {
        votingToken = IERC20(_votingToken);
        proposalThreshold = _proposalThreshold;
        votingPeriod = _votingPeriod;
        quorumVotes = _quorumVotes;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Create new proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        require(votingToken.balanceOf(msg.sender) >= proposalThreshold, "Insufficient voting power");
        require(targets.length == values.length && values.length == signatures.length && signatures.length == calldatas.length, "Invalid proposal");

        proposalCount++;
        uint256 proposalId = proposalCount;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            targets: targets,
            values: values,
            signatures: signatures,
            calldatas: calldatas,
            startBlock: block.number,
            endBlock: block.number + votingPeriod,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            canceled: false
        });

        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            block.number,
            block.number + votingPeriod,
            description
        );

        return proposalId;
    }

    /**
     * @notice Cast vote on proposal
     * @param proposalId Proposal ID
     * @param support 0=against, 1=for, 2=abstain
     */
    function castVote(uint256 proposalId, uint8 support) external {
        require(support <= 2, "Invalid vote");
        Proposal storage proposal = proposals[proposalId];
        require(block.number >= proposal.startBlock && block.number <= proposal.endBlock, "Voting not active");
        require(!proposal.canceled, "Proposal canceled");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 votes = votingToken.balanceOf(msg.sender);
        hasVoted[proposalId][msg.sender] = true;

        if (support == 0) {
            proposal.againstVotes = proposal.againstVotes + votes;
        } else if (support == 1) {
            proposal.forVotes = proposal.forVotes + votes;
        } else {
            proposal.abstainVotes = proposal.abstainVotes + votes;
        }

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    /**
     * @notice Execute proposal if passed
     */
    function execute(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.number > proposal.endBlock, "Voting still active");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");
        require(proposal.forVotes > proposal.againstVotes, "Proposal failed");
        require(proposal.forVotes + proposal.abstainVotes >= quorumVotes, "Quorum not met");

        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(
                abi.encodePacked(bytes4(keccak256(bytes(proposal.signatures[i]))), proposal.calldatas[i])
            );
            require(success, "Transaction execution reverted");
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancel proposal
     */
    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer || hasRole(PROPOSER_ROLE, msg.sender), "Not authorized");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /**
     * @notice Get proposal state
     */
    function state(uint256 proposalId) external view returns (string memory) {
        Proposal memory proposal = proposals[proposalId];
        if (proposal.canceled) return "Canceled";
        if (proposal.executed) return "Executed";
        if (block.number <= proposal.endBlock) return "Active";
        if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes + proposal.abstainVotes < quorumVotes) return "Defeated";
        return "Succeeded";
    }
}

// =====================================================
// PRICE ORACLE
// =====================================================

contract PriceOracle is AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint8 decimals;
    }

    mapping(address => PriceData) public prices;
    mapping(address => bool) public isTokenSupported;

    event PriceUpdated(address indexed token, uint256 price, uint256 timestamp);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Update price for token
     */
    function updatePrice(address token, uint256 price, uint8 decimals) external onlyRole(ORACLE_ROLE) {
        prices[token] = PriceData({
            price: price,
            timestamp: block.timestamp,
            decimals: decimals
        });
        isTokenSupported[token] = true;
        emit PriceUpdated(token, price, block.timestamp);
    }

    /**
     * @notice Get price in USD
     */
    function getPrice(address token) external view returns (uint256) {
        require(isTokenSupported[token], "Token not supported");
        PriceData memory data = prices[token];
        require(block.timestamp - data.timestamp < 1 hours, "Price too old");
        return data.price;
    }

    /**
     * @notice Get price in ETH
     */
    function getPriceETH(address token) external view returns (uint256) {
        require(isTokenSupported[token], "Token not supported");
        require(isTokenSupported[address(0)], "ETH price not set");
        PriceData memory tokenData = prices[token];
        PriceData memory ethData = prices[address(0)];
        require(block.timestamp - tokenData.timestamp < 1 hours, "Price too old");
        return tokenData.price * 1e18 / ethData.price;
    }
}

// =====================================================
// MAIN DEFI PROTOCOL CONTRACT
// =====================================================

contract DeFiProtocol is AccessControl {
    AMMDEX public dex;
    YieldFarm public yieldFarm;
    FlashLoanProvider public flashLoan;
    Governance public governance;
    PriceOracle public oracle;

    IERC20 public immutable protocolToken;

    event ProtocolInitialized(
        address dex,
        address yieldFarm,
        address flashLoan,
        address governance,
        address oracle
    );

    constructor(
        address _protocolToken,
        address _feeRecipient
    ) {
        protocolToken = IERC20(_protocolToken);
        
        // Deploy oracle first
        oracle = new PriceOracle();
        
        // Deploy DEX
        dex = new AMMDEX(_feeRecipient, address(oracle));
        
        // Deploy Flash Loan
        flashLoan = new FlashLoanProvider();
        
        // Deploy Governance
        governance = new Governance(
            _protocolToken,
            1000 * 1e18, // 1000 tokens threshold
            7200, // 1 day voting period (assuming 12s block time)
            10000 * 1e18 // 10000 tokens quorum
        );
        
        // Deploy Yield Farm (will be initialized after DEX)
        yieldFarm = new YieldFarm(
            _protocolToken,
            1 * 1e18, // 1 token per block
            block.number,
            block.number + 100000, // Bonus for 100k blocks
            address(dex)
        );

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        emit ProtocolInitialized(
            address(dex),
            address(yieldFarm),
            address(flashLoan),
            address(governance),
            address(oracle)
        );
    }

    /**
     * @notice Get all protocol addresses
     */
    function getProtocolAddresses() external view returns (
        address _dex,
        address _yieldFarm,
        address _flashLoan,
        address _governance,
        address _oracle
    ) {
        return (address(dex), address(yieldFarm), address(flashLoan), address(governance), address(oracle));
    }
}

