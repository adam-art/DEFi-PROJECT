// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DeFiProtocol.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title DeFi Protocol Deployment Script
 * @notice Helper contract untuk deployment dan setup initial configuration
 */

contract ProtocolToken is ERC20 {
    constructor() ERC20("DeFi Protocol Token", "DEFI") {
        _mint(msg.sender, 10000000 * 10**decimals()); // 10M tokens
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DeFiDeployment {
    DeFiProtocol public protocol;
    ProtocolToken public protocolToken;
    
    address public deployer;
    
    event ProtocolDeployed(
        address indexed protocol,
        address indexed token,
        address indexed deployer
    );
    
    constructor() {
        deployer = msg.sender;
        
        // Deploy protocol token
        protocolToken = new ProtocolToken();
        
        // Deploy main protocol
        protocol = new DeFiProtocol(
            address(protocolToken),
            deployer
        );
        
        emit ProtocolDeployed(
            address(protocol),
            address(protocolToken),
            deployer
        );
    }
    
    /**
     * @notice Setup initial configuration
     */
    function setupInitialConfig() external {
        require(msg.sender == deployer, "Only deployer");
        
        // Grant roles
        protocol.governance().grantRole(
            keccak256("PROPOSER_ROLE"),
            deployer
        );
        
        // Setup oracle with initial prices
        protocol.oracle().grantRole(
            keccak256("ORACLE_ROLE"),
            deployer
        );
        
        // Update ETH price (example: $2000)
        protocol.oracle().updatePrice(
            address(0),
            2000 * 1e8, // 2000 USD with 8 decimals
            8
        );
    }
    
    /**
     * @notice Create initial liquidity pools
     */
    function createInitialPools(
        address token0,
        address token1,
        uint256 fee
    ) external returns (address) {
        require(msg.sender == deployer, "Only deployer");
        return protocol.dex().createPool(token0, token1, fee);
    }
    
    /**
     * @notice Add initial farms
     */
    function addInitialFarms(
        address lpToken,
        address rewardToken,
        uint256 allocPoint
    ) external {
        require(msg.sender == deployer, "Only deployer");
        protocol.yieldFarm().addFarm(lpToken, rewardToken, allocPoint, true);
    }
}

