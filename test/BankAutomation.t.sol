// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Bank.sol";
import "../src/BankAutomation.sol";

/**
 * @title BankAutomationTest
 * @dev BankAutomation合约的测试用例
 */
contract BankAutomationTest is Test {
    Bank public bank;
    BankAutomation public automation;
    address public owner;
    address public user1;
    address public user2;
    
    // 测试参数
    uint256 constant THRESHOLD = 5 ether;
    uint256 constant INTERVAL = 60; // 60秒
    
    function setUp() public {
        // 设置测试账户
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 给测试账户一些以太币
        vm.deal(owner, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        
        // 部署Bank合约
        vm.prank(owner);
        bank = new Bank(THRESHOLD, owner);
        
        // 部署BankAutomation合约（以owner身份）
        vm.prank(owner);
        automation = new BankAutomation(payable(address(bank)), INTERVAL);
    }
    
    /**
     * @dev 测试合约部署
     */
    function testDeployment() public {
        assertEq(address(automation.bankContract()), address(bank));
        assertEq(automation.owner(), owner);
        assertEq(automation.interval(), INTERVAL);
        assertTrue(automation.lastTimeStamp() > 0);
    }
    
    /**
     * @dev 测试checkUpkeep - 条件不满足
     */
    function testCheckUpkeepNotNeeded() public {
        // 存款未达到阈值
        vm.prank(user1);
        bank.deposit{value: 3 ether}();
        
        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }
    
    /**
     * @dev 测试checkUpkeep - 时间未到
     */
    function testCheckUpkeepTimeNotPassed() public {
        // 存款达到阈值
        vm.prank(user1);
        bank.deposit{value: 6 ether}();
        
        // 时间未过
        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }
    
    /**
     * @dev 测试checkUpkeep - 条件满足
     */
    function testCheckUpkeepNeeded() public {
        // 先禁用自动转移，避免在存款时自动触发
        vm.prank(owner);
        bank.toggleAutoTransfer(false);
        
        // 存款达到阈值
        vm.prank(user1);
        bank.deposit{value: 6 ether}();
        
        // 重新启用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(true);
        
        // 时间推进
        vm.warp(block.timestamp + INTERVAL + 1);
        
        (bool upkeepNeeded, bytes memory performData) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        // 验证performData
        (uint256 contractBalance, uint256 threshold) = abi.decode(performData, (uint256, uint256));
        assertEq(contractBalance, 6 ether); // 没有自动转移
        assertEq(threshold, THRESHOLD);
    }
    
    /**
     * @dev 测试checkUpkeep - 自动转移被禁用
     */
    function testCheckUpkeepDisabled() public {
        // 禁用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(false);
        
        // 存款达到阈值
        vm.prank(user1);
        bank.deposit{value: 6 ether}();
        
        // 时间推进
        vm.warp(block.timestamp + INTERVAL + 1);
        
        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }
    
    /**
     * @dev 测试performUpkeep
     */
    function testPerformUpkeep() public {
        // 先禁用自动转移，避免在存款时自动触发
        vm.prank(owner);
        bank.toggleAutoTransfer(false);
        
        // 存款达到阈值
        vm.prank(user1);
        bank.deposit{value: 6 ether}();
        
        // 重新启用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(true);
        
        // 时间推进
        vm.warp(block.timestamp + INTERVAL + 1);
        
        // 验证条件满足
        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        // 记录执行前状态
        uint256 ownerBalanceBefore = owner.balance;
        
        // 执行upkeep
        automation.performUpkeep("");
        
        // 验证执行后状态
        assertEq(owner.balance, ownerBalanceBefore + 3 ether); // 6 ether的一半
        assertEq(bank.getContractBalance(), 3 ether); // 剩余一半
        
        // 验证时间戳更新
        assertEq(automation.lastTimeStamp(), block.timestamp);
    }
    
    /**
     * @dev 测试performUpkeep - 条件不满足时失败
     */
    function testPerformUpkeepNotNeeded() public {
        // 存款未达到阈值
        vm.prank(user1);
        bank.deposit{value: 3 ether}();
        
        vm.expectRevert("Upkeep not needed");
        automation.performUpkeep("");
    }
    
    /**
     * @dev 测试设置间隔
     */
    function testSetInterval() public {
        uint256 newInterval = 120;
        vm.prank(owner);
        automation.setInterval(newInterval);
        assertEq(automation.interval(), newInterval);
    }
    
    /**
     * @dev 测试设置零间隔失败
     */
    function testSetZeroInterval() public {
        vm.prank(owner);
        vm.expectRevert("Interval must be greater than 0");
        automation.setInterval(0);
    }
    
    /**
     * @dev 测试非拥有者设置间隔失败
     */
    function testSetIntervalNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        automation.setInterval(120);
    }
    
    /**
     * @dev 测试手动upkeep
     */
    function testManualUpkeep() public {
        // 先禁用自动转移，避免在存款时自动触发
        vm.prank(owner);
        bank.toggleAutoTransfer(false);
        
        // 存款达到阈值
        vm.prank(user1);
        bank.deposit{value: 6 ether}();
        
        // 重新启用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(true);
        
        // 记录执行前状态
        uint256 ownerBalanceBefore = owner.balance;
        
        // 手动执行upkeep（以owner身份）
        vm.prank(owner);
        automation.manualUpkeep();
        
        // 验证执行后状态
        assertEq(owner.balance, ownerBalanceBefore + 3 ether);
        assertEq(automation.lastTimeStamp(), block.timestamp);
    }
    
    /**
     * @dev 测试getBankInfo
     */
    function testGetBankInfo() public {
        // 存款
        vm.prank(user1);
        bank.deposit{value: 3 ether}();
        
        (
            uint256 contractBalance,
            uint256 threshold,
            bool autoTransferEnabled,
            address target
        ) = automation.getBankInfo();
        
        assertEq(contractBalance, 3 ether);
        assertEq(threshold, THRESHOLD);
        assertTrue(autoTransferEnabled);
        assertEq(target, owner);
    }
    
    /**
     * @dev 测试getNextCheckTime
     */
    function testGetNextCheckTime() public {
        uint256 expectedNextTime = automation.lastTimeStamp() + INTERVAL;
        assertEq(automation.getNextCheckTime(), expectedNextTime);
    }
    
    /**
     * @dev 测试完整的自动化流程
     */
    function testCompleteAutomationFlow() public {
        // 1. 初始状态检查
        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded);
        
        // 2. 先禁用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(false);
        
        // 3. 用户存款，但未达到阈值
        vm.prank(user1);
        bank.deposit{value: 3 ether}();
        
        (upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded);
        
        // 4. 更多存款，达到阈值
        vm.prank(user2);
        bank.deposit{value: 3 ether}();
        
        // 此时Bank合约没有自动转移（因为被禁用）
        assertEq(bank.getContractBalance(), 6 ether);
        
        // 5. 重新启用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(true);
        
        // 6. 时间推进
        vm.warp(block.timestamp + INTERVAL + 1);
        
        // 7. 检查upkeep需要执行
        (upkeepNeeded, ) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        // 8. 执行upkeep
        uint256 ownerBalanceBefore = owner.balance;
        automation.performUpkeep("");
        
        // 9. 验证结果
        assertEq(owner.balance, ownerBalanceBefore + 3 ether);
        assertEq(bank.getContractBalance(), 3 ether);
        assertEq(automation.lastTimeStamp(), block.timestamp);
    }
    
    /**
     * @dev 测试UpkeepPerformed事件
     */
    function testUpkeepPerformedEvent() public {
        // 先禁用自动转移，避免在存款时自动触发
        vm.prank(owner);
        bank.toggleAutoTransfer(false);
        
        // 存款达到阈值
        vm.prank(user1);
        bank.deposit{value: 6 ether}();
        
        // 重新启用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(true);
        
        // 时间推进
        vm.warp(block.timestamp + INTERVAL + 1);
        
        // 期望触发UpkeepPerformed事件（转移后的余额）
        vm.expectEmit(true, true, false, true);
        emit BankAutomation.UpkeepPerformed(block.timestamp, 3 ether);
        
        automation.performUpkeep("");
    }
}