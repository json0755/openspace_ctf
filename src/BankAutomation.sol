// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Bank.sol";

/**
 * @title BankAutomation
 * @dev ChainLink Automation兼容的自动化合约
 * 监控Bank合约余额，当超过阈值时触发自动转移
 * 注意：实际执行频率由ChainLink Automation平台配置，这里的interval主要用于额外的时间控制
 */
contract BankAutomation {
    Bank public immutable bankContract;
    address public owner;
    
    // 上次执行时间
    uint256 public lastTimeStamp;
    
    // 最小执行间隔（秒）- 防止过于频繁执行的保护机制
    uint256 public interval;
    
    // 事件
    event UpkeepPerformed(uint256 timestamp, uint256 contractBalance, uint256 transferAmount);
    event UpkeepFailed(string reason, uint256 timestamp, uint256 contractBalance);
    event IntervalUpdated(uint256 newInterval);
    event UpkeepConditionsChecked(bool timePassed, bool thresholdExceeded, bool autoTransferEnabled, uint256 contractBalance);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /**
     * @dev 构造函数
     * @param _bankContract Bank合约地址
     * @param _interval 检查间隔（秒）
     */
    constructor(address payable _bankContract, uint256 _interval) {
        bankContract = Bank(_bankContract);
        owner = msg.sender;
        interval = _interval;
        lastTimeStamp = block.timestamp;
    }
    
    /**
     * @dev ChainLink Automation检查函数
     * 返回是否需要执行upkeep
     * 注意：ChainLink Automation会根据平台配置的频率调用此函数
     * 这里的interval是额外的保护机制，防止执行过于频繁
     * @return upkeepNeeded 是否需要执行upkeep
     * @return performData 执行数据
     */
    function checkUpkeep(bytes calldata /* checkData */) 
        external 
        view 
        returns (bool upkeepNeeded, bytes memory performData) 
    {
        // 检查最小时间间隔（防止过于频繁执行）
        bool timePassed = (block.timestamp - lastTimeStamp) > interval;
        
        // 检查Bank合约余额是否超过阈值
        uint256 contractBalance = bankContract.getContractBalance();
        uint256 threshold = bankContract.autoTransferThreshold();
        bool thresholdExceeded = contractBalance >= threshold;
        
        // 检查自动转移是否启用
        bool autoTransferEnabled = bankContract.autoTransferEnabled();
        
        // 检查Bank合约的冷却时间
        uint256 lastAutoTransferTime = bankContract.lastAutoTransferTime();
        uint256 autoTransferCooldown = bankContract.autoTransferCooldown();
        bool cooldownPassed = autoTransferCooldown == 0 || (block.timestamp >= lastAutoTransferTime + autoTransferCooldown);
        
        // 检查最小转移金额
        uint256 minimumTransferAmount = bankContract.minimumTransferAmount();
        uint256 potentialTransferAmount = contractBalance / 2;
        bool amountSufficient = potentialTransferAmount >= minimumTransferAmount;
        
        upkeepNeeded = timePassed && thresholdExceeded && autoTransferEnabled && cooldownPassed && amountSufficient;
        performData = abi.encode(contractBalance, threshold, potentialTransferAmount);
    }
    
    /**
     * @dev ChainLink Automation执行函数
     * 当checkUpkeep返回true时执行
     */
    function performUpkeep(bytes calldata performData) external {
        // 重新验证条件
        (bool upkeepNeeded, ) = this.checkUpkeep("");
        require(upkeepNeeded, "Upkeep not needed");
        
        // 解析执行数据（如果有的话）
        uint256 contractBalanceBefore = bankContract.getContractBalance();
        if (performData.length > 0) {
            try this.decodePerformData(performData) returns (uint256 balance, uint256, uint256) {
                contractBalanceBefore = balance;
            } catch {
                // 如果解析失败，使用当前余额
            }
        }
        
        // 更新时间戳
        lastTimeStamp = block.timestamp;
        
        // 触发Bank合约的自动转移
        try bankContract.triggerAutoTransfer() {
            uint256 contractBalanceAfter = bankContract.getContractBalance();
            uint256 actualTransferAmount = contractBalanceBefore > contractBalanceAfter ? 
                contractBalanceBefore - contractBalanceAfter : 0;
            
            emit UpkeepPerformed(block.timestamp, contractBalanceAfter, actualTransferAmount);
        } catch Error(string memory reason) {
            emit UpkeepFailed(reason, block.timestamp, bankContract.getContractBalance());
        } catch (bytes memory lowLevelData) {
            emit UpkeepFailed(
                string(abi.encodePacked("Low level error: ", lowLevelData)), 
                block.timestamp, 
                bankContract.getContractBalance()
            );
        }
    }
    
    /**
     * @dev 设置最小执行间隔
     * 注意：这不会影响ChainLink Automation的调用频率，那个需要在平台上配置
     * 这里的间隔是额外的保护机制，防止合约执行过于频繁
     * @param _interval 新的最小执行间隔（秒）
     */
    function setInterval(uint256 _interval) external onlyOwner {
        require(_interval > 0, "Interval must be greater than 0");
        interval = _interval;
        emit IntervalUpdated(_interval);
    }
    
    /**
     * @dev 手动触发upkeep（仅用于测试）
     */
    function manualUpkeep() external onlyOwner {
        uint256 contractBalanceBefore = bankContract.getContractBalance();
        lastTimeStamp = block.timestamp;
        
        try bankContract.triggerAutoTransfer() {
            uint256 contractBalanceAfter = bankContract.getContractBalance();
            uint256 actualTransferAmount = contractBalanceBefore > contractBalanceAfter ? 
                contractBalanceBefore - contractBalanceAfter : 0;
            
            emit UpkeepPerformed(block.timestamp, contractBalanceAfter, actualTransferAmount);
        } catch Error(string memory reason) {
            emit UpkeepFailed(reason, block.timestamp, bankContract.getContractBalance());
        } catch (bytes memory lowLevelData) {
            emit UpkeepFailed(
                string(abi.encodePacked("Manual upkeep failed: ", lowLevelData)), 
                block.timestamp, 
                bankContract.getContractBalance()
            );
        }
    }
    
    /**
     * @dev 获取Bank合约信息
     * @return contractBalance 合约余额
     * @return threshold 阈值
     * @return autoTransferEnabled 是否启用自动转移
     * @return target 转移目标地址
     */
    function getBankInfo() external view returns (
        uint256 contractBalance,
        uint256 threshold,
        bool autoTransferEnabled,
        address target
    ) {
        contractBalance = bankContract.getContractBalance();
        threshold = bankContract.autoTransferThreshold();
        autoTransferEnabled = bankContract.autoTransferEnabled();
        target = bankContract.autoTransferTarget();
    }
    
    /**
     * @dev 获取下次检查时间
     * @return nextCheckTime 下次检查的时间戳
     */
    function getNextCheckTime() external view returns (uint256 nextCheckTime) {
        nextCheckTime = lastTimeStamp + interval;
    }
    
    /**
     * @dev 解析performData的辅助函数
     * @param data 要解析的数据
     * @return balance 合约余额
     * @return threshold 阈值
     * @return transferAmount 转移金额
     */
    function decodePerformData(bytes calldata data) external pure returns (
        uint256 balance,
        uint256 threshold,
        uint256 transferAmount
    ) {
        (balance, threshold, transferAmount) = abi.decode(data, (uint256, uint256, uint256));
    }
}