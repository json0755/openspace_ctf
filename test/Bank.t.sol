// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Bank.sol";

/**
 * @title BankTest
 * @dev Bank合约的测试用例
 */
contract BankTest is Test {
    Bank public bank;
    address public owner;
    address public user1;
    address public user2;
    
    // 测试用的金额
    uint256 constant DEPOSIT_AMOUNT = 1 ether;
    uint256 constant WITHDRAW_AMOUNT = 0.5 ether;
    uint256 constant TRANSFER_AMOUNT = 0.3 ether;
    
    function setUp() public {
        // 设置测试账户
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 给测试账户一些以太币
        vm.deal(owner, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        
        // 使用owner身份部署Bank合约
        vm.prank(owner);
        bank = new Bank(5 ether, owner); // 设置阈值为5 ether，目标地址为owner
    }
    
    /**
     * @dev 测试合约部署
     */
    function testDeployment() public {
        assertEq(bank.owner(), owner);
        assertEq(bank.getContractBalance(), 0);
    }
    
    /**
     * @dev 测试存款功能
     */
    function testDeposit() public {
        vm.startPrank(user1);
        
        // 记录存款前的状态
        uint256 initialBalance = bank.getBalance(user1);
        uint256 initialContractBalance = bank.getContractBalance();
        
        // 执行存款
        bank.deposit{value: DEPOSIT_AMOUNT}();
        
        // 验证存款后的状态
        assertEq(bank.getBalance(user1), initialBalance + DEPOSIT_AMOUNT);
        assertEq(bank.getContractBalance(), initialContractBalance + DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试存款事件
     */
    function testDepositEvent() public {
        vm.startPrank(user1);
        
        // 期望触发Deposit事件
        vm.expectEmit(true, false, false, true);
        emit Bank.Deposit(user1, DEPOSIT_AMOUNT);
        
        bank.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试零金额存款失败
     */
    function testDepositZeroAmount() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Deposit amount must be greater than 0");
        bank.deposit{value: 0}();
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试取款功能
     */
    function testWithdraw() public {
        vm.startPrank(user1);
        
        // 先存款
        bank.deposit{value: DEPOSIT_AMOUNT}();
        
        // 记录取款前的状态
        uint256 initialBalance = bank.getBalance(user1);
        uint256 initialContractBalance = bank.getContractBalance();
        uint256 initialUserEthBalance = user1.balance;
        
        // 执行取款
        bank.withdraw(WITHDRAW_AMOUNT);
        
        // 验证取款后的状态
        assertEq(bank.getBalance(user1), initialBalance - WITHDRAW_AMOUNT);
        assertEq(bank.getContractBalance(), initialContractBalance - WITHDRAW_AMOUNT);
        assertEq(user1.balance, initialUserEthBalance + WITHDRAW_AMOUNT);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试余额不足时取款失败
     */
    function testWithdrawInsufficientBalance() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Insufficient balance");
        bank.withdraw(WITHDRAW_AMOUNT);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试转账功能
     */
    function testTransfer() public {
        vm.startPrank(user1);
        
        // 先存款
        bank.deposit{value: DEPOSIT_AMOUNT}();
        
        // 记录转账前的状态
        uint256 user1InitialBalance = bank.getBalance(user1);
        uint256 user2InitialBalance = bank.getBalance(user2);
        
        // 执行转账
        bank.transfer(user2, TRANSFER_AMOUNT);
        
        // 验证转账后的状态
        assertEq(bank.getBalance(user1), user1InitialBalance - TRANSFER_AMOUNT);
        assertEq(bank.getBalance(user2), user2InitialBalance + TRANSFER_AMOUNT);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试向零地址转账失败
     */
    function testTransferToZeroAddress() public {
        vm.startPrank(user1);
        
        bank.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.expectRevert("Cannot transfer to zero address");
        bank.transfer(address(0), TRANSFER_AMOUNT);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试向自己转账失败
     */
    function testTransferToSelf() public {
        vm.startPrank(user1);
        
        bank.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.expectRevert("Cannot transfer to yourself");
        bank.transfer(user1, TRANSFER_AMOUNT);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试查询余额功能
     */
    function testGetBalance() public {
        vm.startPrank(user1);
        
        // 初始余额应为0
        assertEq(bank.getBalance(user1), 0);
        assertEq(bank.getMyBalance(), 0);
        
        // 存款后查询余额
        bank.deposit{value: DEPOSIT_AMOUNT}();
        assertEq(bank.getBalance(user1), DEPOSIT_AMOUNT);
        assertEq(bank.getMyBalance(), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试紧急提取功能（仅拥有者）
     */
    function testEmergencyWithdraw() public {
        // 用户存款
        vm.prank(user1);
        bank.deposit{value: DEPOSIT_AMOUNT}();
        
        // 记录拥有者初始余额
        uint256 ownerInitialBalance = owner.balance;
        
        // 拥有者执行紧急提取
        vm.prank(owner);
        bank.emergencyWithdraw();
        
        // 验证结果
        assertEq(bank.getContractBalance(), 0);
        assertEq(owner.balance, ownerInitialBalance + DEPOSIT_AMOUNT);
    }
    
    /**
     * @dev 测试非拥有者调用紧急提取失败
     */
    function testEmergencyWithdrawNotOwner() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Only owner can call this function");
        bank.emergencyWithdraw();
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试receive函数
     */
    function testReceiveFunction() public {
        vm.startPrank(user1);
        
        // 直接向合约发送以太币
        (bool success, ) = address(bank).call{value: DEPOSIT_AMOUNT}("");
        require(success, "Direct transfer failed");
        
        // 验证余额更新
        assertEq(bank.getBalance(user1), DEPOSIT_AMOUNT);
        assertEq(bank.getContractBalance(), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试fallback函数
     */
    function testFallbackFunction() public {
        vm.startPrank(user1);
        
        // 调用不存在的函数
        (bool success, ) = address(bank).call{value: DEPOSIT_AMOUNT}(abi.encodeWithSignature("nonExistentFunction()"));
        require(success, "Fallback call failed");
        
        // 验证余额更新
        assertEq(bank.getBalance(user1), DEPOSIT_AMOUNT);
        assertEq(bank.getContractBalance(), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试完整的用户交互流程
     */
    function testCompleteUserFlow() public {
        // User1存款
        vm.startPrank(user1);
        bank.deposit{value: 2 ether}();
        assertEq(bank.getMyBalance(), 2 ether);
        vm.stopPrank();
        
        // User2存款
        vm.startPrank(user2);
        bank.deposit{value: 1 ether}();
        assertEq(bank.getMyBalance(), 1 ether);
        vm.stopPrank();
        
        // User1向User2转账
        vm.startPrank(user1);
        bank.transfer(user2, 0.5 ether);
        assertEq(bank.getMyBalance(), 1.5 ether);
        vm.stopPrank();
        
        // 验证User2余额
        assertEq(bank.getBalance(user2), 1.5 ether);
        
        // User2取款
        vm.startPrank(user2);
        uint256 user2EthBefore = user2.balance;
        bank.withdraw(1 ether);
        assertEq(bank.getMyBalance(), 0.5 ether);
        assertEq(user2.balance, user2EthBefore + 1 ether);
        vm.stopPrank();
        
        // 验证合约总余额
        assertEq(bank.getContractBalance(), 2 ether); // 1.5 + 0.5
    }
    
    /**
     * @dev 测试自动转移功能
     */
    function testAutoTransfer() public {
        // 记录owner初始余额
        uint256 ownerInitialBalance = owner.balance;
        
        // User1存款，但未达到阈值
        vm.prank(user1);
        bank.deposit{value: 3 ether}();
        
        // 验证没有自动转移
        assertEq(bank.getContractBalance(), 3 ether);
        assertEq(owner.balance, ownerInitialBalance);
        
        // User2存款，达到阈值
        vm.prank(user2);
        bank.deposit{value: 3 ether}();
        
        // 验证自动转移发生（转移一半，即3 ether）
        assertEq(bank.getContractBalance(), 3 ether);
        assertEq(owner.balance, ownerInitialBalance + 3 ether);
    }
    
    /**
     * @dev 测试自动转移事件
     */
    function testAutoTransferEvent() public {
        vm.prank(user1);
        bank.deposit{value: 3 ether}();
        
        // 期望触发AutoTransfer事件
        vm.expectEmit(true, false, false, true);
        emit Bank.AutoTransfer(3 ether, owner);
        
        vm.prank(user2);
        bank.deposit{value: 3 ether}();
    }
    
    /**
     * @dev 测试设置自动转移阈值
     */
    function testSetAutoTransferThreshold() public {
        vm.prank(owner);
        bank.setAutoTransferThreshold(10 ether);
        
        assertEq(bank.autoTransferThreshold(), 10 ether);
    }
    
    /**
     * @dev 测试非拥有者设置阈值失败
     */
    function testSetThresholdNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        bank.setAutoTransferThreshold(10 ether);
    }
    
    /**
     * @dev 测试设置自动转移目标地址
     */
    function testSetAutoTransferTarget() public {
        vm.prank(owner);
        bank.setAutoTransferTarget(user1);
        
        assertEq(bank.autoTransferTarget(), user1);
    }
    
    /**
     * @dev 测试设置零地址为目标失败
     */
    function testSetTargetZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Target cannot be zero address");
        bank.setAutoTransferTarget(address(0));
    }
    
    /**
     * @dev 测试切换自动转移功能
     */
    function testToggleAutoTransfer() public {
        // 初始状态应该是启用的
        assertTrue(bank.autoTransferEnabled());
        
        // 禁用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(false);
        assertFalse(bank.autoTransferEnabled());
        
        // 存款超过阈值，但不应该自动转移
        uint256 ownerInitialBalance = owner.balance;
        vm.prank(user1);
        bank.deposit{value: 6 ether}();
        
        assertEq(bank.getContractBalance(), 6 ether);
        assertEq(owner.balance, ownerInitialBalance);
        
        // 重新启用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(true);
        assertTrue(bank.autoTransferEnabled());
    }
    
    /**
     * @dev 测试手动触发自动转移
     */
    function testManualAutoTransfer() public {
        // 先禁用自动转移，避免在存款时自动触发
        vm.prank(owner);
        bank.toggleAutoTransfer(false);
        
        // 存款超过阈值
        vm.prank(user1);
        bank.deposit{value: 6 ether}();
        
        // 验证没有自动转移
        assertEq(bank.getContractBalance(), 6 ether);
        
        // 重新启用自动转移
        vm.prank(owner);
        bank.toggleAutoTransfer(true);
        
        // 手动触发自动转移
        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        bank.manualAutoTransfer();
        
        // 验证转移了一半（3 ether）
        assertEq(owner.balance, ownerBalanceBefore + 3 ether);
        assertEq(bank.getContractBalance(), 3 ether);
    }
}