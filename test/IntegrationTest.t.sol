// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Bank.sol";
import "../src/BankAutomation.sol";

/**
 * @title IntegrationTest
 * @dev 集成测试：验证Bank合约和BankAutomation合约的完整自动化流程
 * 测试场景：
 * - Bank合约阈值设置为0.1ETH
 * - BankAutomation间隔设置为30秒
 * - 验证当存款超过阈值时自动转移一半资金到指定地址
 */
contract IntegrationTest is Test {
    Bank public bank;
    BankAutomation public automation;
    address public owner;
    address public user1;
    address public user2;
    address public targetWallet;
    
    // 测试参数 - 按照用户需求设置
    uint256 constant THRESHOLD = 0.1 ether;  // 0.1 ETH阈值
    uint256 constant INTERVAL = 30;          // 30秒间隔
    
    event AutoTransfer(uint256 amount, address indexed to);
    event UpkeepPerformed(uint256 timestamp, uint256 contractBalance, uint256 transferAmount);
    
    function setUp() public {
        // 设置测试账户
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        targetWallet = makeAddr("targetWallet"); // 模拟用户的钱包地址
        
        // 给测试账户一些以太币
        vm.deal(owner, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        
        // 部署Bank合约 - 按照用户需求设置参数
        vm.prank(owner);
        bank = new Bank(THRESHOLD, targetWallet);
        
        // 部署BankAutomation合约 - 按照用户需求设置参数
        vm.prank(owner);
        automation = new BankAutomation(payable(address(bank)), INTERVAL);
    }
    
    /**
     * @dev 测试合约部署是否符合用户需求
     */
    function testDeploymentWithUserRequirements() public {
        // 验证Bank合约配置
        assertEq(bank.autoTransferThreshold(), THRESHOLD, "Threshold should be 0.1 ETH");
        assertEq(bank.autoTransferTarget(), targetWallet, "Target should be user wallet");
        assertTrue(bank.autoTransferEnabled(), "Auto transfer should be enabled");
        assertEq(bank.owner(), owner, "Owner should be correct");
        
        // 验证BankAutomation合约配置
        assertEq(address(automation.bankContract()), address(bank), "Bank contract address should match");
        assertEq(automation.interval(), INTERVAL, "Interval should be 30 seconds");
        assertEq(automation.owner(), owner, "Automation owner should be correct");
    }
    
    /**
     * @dev 测试存款未达到阈值时不触发自动转移
     */
    function testDepositBelowThreshold() public {
        uint256 depositAmount = 0.05 ether; // 低于0.1 ETH阈值
        uint256 targetBalanceBefore = targetWallet.balance;
        
        // 用户存款
        vm.prank(user1);
        bank.deposit{value: depositAmount}();
        
        // 验证存款成功
        assertEq(bank.getBalance(user1), depositAmount, "User balance should match deposit");
        assertEq(address(bank).balance, depositAmount, "Contract balance should match deposit");
        
        // 验证未触发自动转移
        assertEq(targetWallet.balance, targetBalanceBefore, "Target wallet balance should not change");
        
        // 验证checkUpkeep返回false（因为未达到阈值）
        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded, "Upkeep should not be needed below threshold");
    }
    
    /**
     * @dev 测试存款达到阈值时触发自动转移
     */
    function testDepositAboveThresholdTriggersAutoTransfer() public {
        uint256 depositAmount = 0.2 ether; // 超过0.1 ETH阈值
        uint256 targetBalanceBefore = targetWallet.balance;
        
        // 用户存款
        vm.prank(user1);
        bank.deposit{value: depositAmount}();
        
        // 验证自动转移已触发（在deposit函数中自动调用）
        uint256 expectedTransferAmount = depositAmount / 2; // 转移一半
        uint256 expectedContractBalance = depositAmount - expectedTransferAmount;
        
        assertEq(targetWallet.balance, targetBalanceBefore + expectedTransferAmount, "Target wallet should receive half of deposit");
        assertEq(address(bank).balance, expectedContractBalance, "Contract should retain half of deposit");
        
        // 验证用户余额（用户余额不受自动转移影响，仍然是存款金额）
        assertEq(bank.getBalance(user1), depositAmount, "User balance should match deposit");
    }
    
    /**
     * @dev 测试ChainLink Automation的完整流程
     */
    function testChainLinkAutomationFlow() public {
        // 第一步：存款但不超过阈值
        vm.prank(user1);
        bank.deposit{value: 0.05 ether}();
        
        // 验证checkUpkeep返回false
        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded, "Upkeep should not be needed below threshold");
        
        // 第二步：禁用自动转移，然后存款超过阈值
        vm.prank(owner);
        bank.toggleAutoTransfer(false);
        
        vm.prank(user2);
        bank.deposit{value: 0.08 ether}();
        
        // 现在合约总余额为0.13 ETH，超过0.1 ETH阈值，但自动转移被禁用
        uint256 contractBalance = address(bank).balance;
        assertEq(contractBalance, 0.13 ether, "Contract balance should be total deposits");
        
        // 重新启用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(true);
        
        // 第三步：模拟时间推进（超过30秒间隔）
        vm.warp(block.timestamp + INTERVAL + 1);
        
        // 第四步：检查是否需要执行upkeep
        (upkeepNeeded, ) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed when threshold exceeded and time passed");
        
        // 第五步：执行upkeep
        uint256 targetBalanceBefore = targetWallet.balance;
        uint256 contractBalanceBefore = address(bank).balance;
        
        // 执行upkeep
        automation.performUpkeep("");
        
        // 验证自动转移结果
        uint256 expectedTransferAmount = contractBalanceBefore / 2;
        assertEq(targetWallet.balance, targetBalanceBefore + expectedTransferAmount, "Target should receive half of contract balance");
        assertEq(address(bank).balance, contractBalanceBefore - expectedTransferAmount, "Contract should retain half of balance");
    }
    
    /**
     * @dev 测试多次存款和自动转移的累积效果
     */
    function testMultipleDepositsAndTransfers() public {
        uint256 targetBalanceBefore = targetWallet.balance;
        
        // 第一次存款：0.15 ETH（超过阈值）
        vm.prank(user1);
        bank.deposit{value: 0.15 ether}();
        
        uint256 firstTransfer = 0.15 ether / 2;
        assertEq(targetWallet.balance, targetBalanceBefore + firstTransfer, "First transfer should be correct");
        
        // 记录第一次转移后的状态
        uint256 contractBalanceAfterFirst = address(bank).balance;
        uint256 targetBalanceAfterFirst = targetWallet.balance;
        
        // 等待间隔时间
        vm.warp(block.timestamp + INTERVAL + 1);
        
        // 第二次存款：0.12 ETH
        vm.prank(user2);
        bank.deposit{value: 0.12 ether}();
        
        // 第二次存款后的合约余额 = 第一次剩余 + 第二次存款
        uint256 balanceBeforeSecondTransfer = contractBalanceAfterFirst + 0.12 ether;
        uint256 secondTransfer = balanceBeforeSecondTransfer / 2;
        
        assertEq(targetWallet.balance, targetBalanceAfterFirst + secondTransfer, "Second transfer should be correct");
    }
    
    /**
     * @dev 测试时间间隔保护机制
     */
    function testIntervalProtection() public {
        // 存款超过阈值
        vm.prank(user1);
        bank.deposit{value: 0.2 ether}();
        
        // 立即检查upkeep（时间间隔未过）
        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded, "Upkeep should not be needed when interval not passed");
        
        // 推进时间但不足30秒
        vm.warp(block.timestamp + 20);
        (upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded, "Upkeep should not be needed when interval not fully passed");
        
        // 推进时间超过30秒
        vm.warp(block.timestamp + 15); // 总共35秒
        (upkeepNeeded, ) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed when interval passed");
    }
    
    /**
     * @dev 测试自动转移禁用时的行为
     */
    function testDisabledAutoTransfer() public {
        // 禁用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(false);
        
        // 存款超过阈值
        vm.prank(user1);
        bank.deposit{value: 0.2 ether}();
        
        // 推进时间
        vm.warp(block.timestamp + INTERVAL + 1);
        
        // 验证checkUpkeep返回false（因为自动转移被禁用）
        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded, "Upkeep should not be needed when auto transfer disabled");
    }
    
    /**
     * @dev 测试手动upkeep功能
     */
    function testManualUpkeep() public {
        // 存款超过阈值
        vm.prank(user1);
        bank.deposit{value: 0.2 ether}();
        
        uint256 targetBalanceBefore = targetWallet.balance;
        uint256 contractBalanceBefore = address(bank).balance;
        
        // 手动触发upkeep
        vm.prank(owner);
        automation.manualUpkeep();
        
        // 验证转移结果
        uint256 expectedTransferAmount = contractBalanceBefore / 2;
        assertEq(targetWallet.balance, targetBalanceBefore + expectedTransferAmount, "Manual upkeep should trigger transfer");
    }
    
    /**
     * @dev 测试获取Bank信息功能
     */
    function testGetBankInfo() public {
        // 存款
        vm.prank(user1);
        bank.deposit{value: 0.15 ether}();
        
        // 获取Bank信息
        (uint256 contractBalance, uint256 threshold, bool autoTransferEnabled, address target) = automation.getBankInfo();
        
        // 验证信息正确性
        assertEq(contractBalance, address(bank).balance, "Contract balance should match");
        assertEq(threshold, THRESHOLD, "Threshold should match");
        assertTrue(autoTransferEnabled, "Auto transfer should be enabled");
        assertEq(target, targetWallet, "Target should match");
    }
    
    /**
     * @dev 测试完整的用户流程
     */
    function testCompleteUserFlow() public {
        console.log("=== Starting Complete User Flow Test ===");
        console.log("Threshold setting:", THRESHOLD);
        console.log("Interval setting:", INTERVAL, "seconds");
        console.log("Target wallet:", targetWallet);
        
        uint256 initialTargetBalance = targetWallet.balance;
        console.log("Target wallet initial balance:", initialTargetBalance);
        
        // User1 deposits 0.06 ETH (below threshold)
        console.log("\n--- User1 deposits 0.06 ETH ---");
        vm.prank(user1);
        bank.deposit{value: 0.06 ether}();
        console.log("Contract balance:", address(bank).balance);
        console.log("Target wallet balance:", targetWallet.balance);
        
        // User2 deposits 0.08 ETH (total reaches threshold)
        console.log("\n--- User2 deposits 0.08 ETH ---");
        vm.prank(user2);
        bank.deposit{value: 0.08 ether}();
        console.log("Contract balance:", address(bank).balance);
        console.log("Target wallet balance:", targetWallet.balance);
        
        // Verify auto transfer triggered
        uint256 expectedBalance = initialTargetBalance + (0.14 ether / 2);
        assertEq(targetWallet.balance, expectedBalance, "Auto transfer should be triggered");
        
        console.log("\n=== Test Completed ===");
        console.log("All functions work as expected");
    }
}