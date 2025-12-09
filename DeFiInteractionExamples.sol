// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DeFiProtocol.sol";

/**
 * @title DeFi Interaction Examples
 * @notice Contoh penggunaan semua fitur DeFi Protocol
 */

contract DeFiExamples {
    DeFiProtocol public protocol;
    
    constructor(address _protocol) {
        protocol = DeFiProtocol(_protocol);
    }
    
    // =====================================================
    // DEX EXAMPLES
    // =====================================================
    
    /**
     * @notice Contoh: Buat liquidity pool baru
     */
    function exampleCreatePool(
        address token0,
        address token1,
        uint256 fee
    ) external returns (address) {
        return protocol.dex().createPool(token0, token1, fee);
    }
    
    /**
     * @notice Contoh: Tambah liquidity ke pool
     */
    function exampleAddLiquidity(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external {
        protocol.dex().addLiquidity(
            token0,
            token1,
            amount0,
            amount1,
            amount0 * 95 / 100, // 5% slippage tolerance
            amount1 * 95 / 100,
            msg.sender
        );
    }
    
    /**
     * @notice Contoh: Swap tokens
     */
    function exampleSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external {
        uint256 minOut = protocol.dex().getAmountOut(
            amountIn,
            tokenIn,
            tokenOut
        );
        
        protocol.dex().swap(
            tokenIn,
            tokenOut,
            amountIn,
            minOut * 95 / 100, // 5% slippage
            msg.sender
        );
    }
    
    // =====================================================
    // YIELD FARMING EXAMPLES
    // =====================================================
    
    /**
     * @notice Contoh: Stake LP tokens untuk farming
     */
    function exampleStakeLP(
        address lpToken,
        uint256 amount
    ) external {
        protocol.yieldFarm().deposit(lpToken, amount);
    }
    
    /**
     * @notice Contoh: Check pending rewards
     */
    function exampleCheckRewards(
        address lpToken
    ) external view returns (uint256) {
        return protocol.yieldFarm().pendingRewards(lpToken, msg.sender);
    }
    
    /**
     * @notice Contoh: Harvest rewards
     */
    function exampleHarvest(address lpToken) external {
        protocol.yieldFarm().harvest(lpToken);
    }
    
    /**
     * @notice Contoh: Withdraw LP tokens
     */
    function exampleWithdrawLP(
        address lpToken,
        uint256 amount
    ) external {
        protocol.yieldFarm().withdraw(lpToken, amount);
    }
    
    // =====================================================
    // FLASH LOAN EXAMPLES
    // =====================================================
    
    /**
     * @notice Contoh: Menggunakan flash loan untuk arbitrage
     */
    function exampleFlashLoanArbitrage(
        address token,
        uint256 amount,
        address dex1,
        address dex2
    ) external {
        bytes memory params = abi.encode(dex1, dex2, token, amount);
        
        protocol.flashLoan().flashLoan(
            token,
            amount,
            address(this),
            params
        );
    }
    
    /**
     * @notice Implementasi flash loan receiver untuk arbitrage
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == address(protocol.flashLoan()), "Invalid caller");
        
        // Decode params
        (address dex1, address dex2, address token, uint256 amount) = 
            abi.decode(params, (address, address, address, uint256));
        
        // Logic arbitrage di sini
        // 1. Swap di DEX1 dengan harga lebih rendah
        // 2. Swap di DEX2 dengan harga lebih tinggi
        // 3. Profit = selisih - premium
        
        // Repay loan + premium
        uint256 repayAmount = amounts[0] + premiums[0];
        IERC20(assets[0]).transfer(address(protocol.flashLoan()), repayAmount);
        
        return true;
    }
    
    // =====================================================
    // GOVERNANCE EXAMPLES
    // =====================================================
    
    /**
     * @notice Contoh: Buat governance proposal
     */
    function exampleCreateProposal(
        address target,
        bytes memory calldata_,
        string memory description
    ) external returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = target;
        
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        
        string[] memory signatures = new string[](1);
        signatures[0] = "setProtocolFee(uint256)";
        
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = calldata_;
        
        return protocol.governance().propose(
            targets,
            values,
            signatures,
            calldatas,
            description
        );
    }
    
    /**
     * @notice Contoh: Vote pada proposal
     */
    function exampleVote(
        uint256 proposalId,
        uint8 support // 0=against, 1=for, 2=abstain
    ) external {
        protocol.governance().castVote(proposalId, support);
    }
    
    /**
     * @notice Contoh: Execute proposal
     */
    function exampleExecuteProposal(uint256 proposalId) external {
        protocol.governance().execute(proposalId);
    }
    
    // =====================================================
    // COMPLETE WORKFLOW EXAMPLES
    // =====================================================
    
    /**
     * @notice Workflow lengkap: Dari trading hingga yield farming
     */
    function completeWorkflow(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external {
        // 1. Buat pool jika belum ada
        try protocol.dex().createPool(tokenA, tokenB, 30) {} catch {}
        
        // 2. Add liquidity
        protocol.dex().addLiquidity(
            tokenA,
            tokenB,
            amountA,
            amountB,
            amountA * 95 / 100,
            amountB * 95 / 100,
            address(this)
        );
        
        // 3. Get LP token address
        address lpToken = address(protocol.dex().pools(tokenA, tokenB).lpToken);
        uint256 lpBalance = IERC20(lpToken).balanceOf(address(this));
        
        // 4. Approve dan stake LP tokens
        IERC20(lpToken).approve(address(protocol.yieldFarm()), lpBalance);
        protocol.yieldFarm().deposit(lpToken, lpBalance);
    }
    
    /**
     * @notice Workflow: Flash loan untuk leverage trading
     */
    function leverageTradingWorkflow(
        address collateralToken,
        address borrowToken,
        uint256 borrowAmount
    ) external {
        bytes memory params = abi.encode(collateralToken, borrowToken);
        
        protocol.flashLoan().flashLoan(
            borrowToken,
            borrowAmount,
            address(this),
            params
        );
    }
    
    // =====================================================
    // HELPER FUNCTIONS
    // =====================================================
    
    /**
     * @notice Get protocol stats
     */
    function getProtocolStats() external view returns (
        address dex,
        address yieldFarm,
        address flashLoan,
        address governance,
        address oracle
    ) {
        return protocol.getProtocolAddresses();
    }
    
    /**
     * @notice Get pool reserves
     */
    function getPoolReserves(
        address token0,
        address token1
    ) external view returns (uint256 reserve0, uint256 reserve1) {
        AMMDEX.Pool memory pool = protocol.dex().pools(token0, token1);
        return (pool.reserve0, pool.reserve1);
    }
    
    /**
     * @notice Calculate swap output
     */
    function calculateSwapOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        return protocol.dex().getAmountOut(tokenIn, tokenOut, amountIn);
    }
}

