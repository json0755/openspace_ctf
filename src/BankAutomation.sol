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
    event UpkeepPerformed(uint256 timestamp, uint256 contractBalance);
    event IntervalUpdated(uint256 newInterval);
    
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
        
        upkeepNeeded = timePassed && thresholdExceeded && autoTransferEnabled;
        performData = abi.encode(contractBalance, threshold);
    }
    
    /**
     * @dev ChainLink Automation执行函数
     * 当checkUpkeep返回true时执行
     */
    function performUpkeep(bytes calldata /* performData */) external {
        // 重新验证条件
        (bool upkeepNeeded, ) = this.checkUpkeep("");
        require(upkeepNeeded, "Upkeep not needed");
        
        // 更新时间戳
        lastTimeStamp = block.timestamp;
        
        // 触发Bank合约的自动转移
        try bankContract.triggerAutoTransfer() {
            uint256 contractBalance = bankContract.getContractBalance();
            emit UpkeepPerformed(block.timestamp, contractBalance);
        } catch {
            // 如果调用失败，记录但不回滚
            // 这样可以避免因为Bank合约问题导致整个upkeep失败
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
        lastTimeStamp = block.timestamp;
        bankContract.triggerAutoTransfer();
        
        uint256 contractBalance = bankContract.getContractBalance();
        emit UpkeepPerformed(block.timestamp, contractBalance);
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
}