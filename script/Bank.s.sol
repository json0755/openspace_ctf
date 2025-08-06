// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Bank.sol";
import "../src/BankAutomation.sol";

/**
 * @title BankScript
 * @dev Bank合约和BankAutomation合约的部署脚本
 */
contract BankScript is Script {
    function setUp() public {}

    function run() public {
        // 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 配置参数
        uint256 autoTransferThreshold = vm.envOr("AUTO_TRANSFER_THRESHOLD", uint256(5 ether));
        address autoTransferTarget = vm.envOr("AUTO_TRANSFER_TARGET", vm.addr(deployerPrivateKey));
        uint256 automationInterval = vm.envOr("AUTOMATION_INTERVAL", uint256(300)); // 5分钟
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 部署Bank合约
        Bank bank = new Bank(autoTransferThreshold, autoTransferTarget);
        
        // 部署BankAutomation合约
        BankAutomation automation = new BankAutomation(payable(address(bank)), automationInterval);
        
        // 输出合约地址和配置
        console.log("=== Bank Contract Deployment ===");
        console.log("Bank contract deployed at:", address(bank));
        console.log("Owner:", bank.owner());
        console.log("Auto transfer threshold:", autoTransferThreshold);
        console.log("Auto transfer target:", autoTransferTarget);
        console.log("Auto transfer enabled:", bank.autoTransferEnabled());
        
        console.log("\n=== BankAutomation Contract Deployment ===");
        console.log("BankAutomation contract deployed at:", address(automation));
        console.log("Automation owner:", automation.owner());
        console.log("Check interval (seconds):", automationInterval);
        
        console.log("\n=== Setup Instructions ===");
        console.log("1. Register the BankAutomation contract with ChainLink Automation");
        console.log("2. Fund the automation contract with LINK tokens");
        console.log("3. Configure upkeep parameters in ChainLink Automation UI");
        console.log("4. Monitor automation performance through events");
        
        // 停止广播
        vm.stopBroadcast();
    }
}