# Bank 合约

一个简单而功能完整的银行智能合约，实现了基本的存款、取款、转账等功能。

## 功能特性

### 核心功能
- **存款 (Deposit)**: 用户可以向合约存入以太币
- **取款 (Withdraw)**: 用户可以从合约中取出自己的资金
- **转账 (Transfer)**: 用户可以向其他地址转账
- **余额查询**: 查询自己或他人的余额
- **紧急提取**: 合约拥有者可以提取所有资金（紧急情况）

### 安全特性
- **重入攻击防护**: 使用 Checks-Effects-Interactions 模式
- **权限控制**: 只有拥有者可以执行紧急提取
- **输入验证**: 对所有输入参数进行验证
- **事件记录**: 记录所有重要操作的事件

## 合约接口

### 主要函数

#### 基础功能
- `deposit()`: 存款函数，用户可以向合约存入以太币
- `withdraw(uint256 amount)`: 取款函数，用户可以取出指定数量的以太币
- `transfer(address to, uint256 amount)`: 转账函数，用户可以向其他地址转账
- `getBalance(address user)`: 查询指定地址的余额
- `getMyBalance()`: 查询调用者的余额
- `getContractBalance()`: 查询合约总余额

#### 管理功能（仅拥有者）
- `emergencyWithdraw()`: 紧急提取合约中的所有资金
- `setAutoTransferThreshold(uint256 _threshold)`: 设置自动转移阈值
- `setAutoTransferTarget(address _target)`: 设置自动转移目标地址
- `toggleAutoTransfer(bool _enabled)`: 切换自动转移功能
- `manualAutoTransfer()`: 手动触发自动转移检查（仅拥有者）

#### 自动化功能
- `triggerAutoTransfer()`: 外部触发自动转移检查（用于自动化合约）

### 事件

```solidity
event Deposit(address indexed user, uint256 amount);
event Withdraw(address indexed user, uint256 amount);
event Transfer(address indexed from, address indexed to, uint256 amount);
```

## 使用示例

### 1. 存款
```solidity
// 直接调用deposit函数
bank.deposit{value: 1 ether}();

// 或者直接向合约发送以太币（会自动调用deposit）
payable(bankAddress).transfer(1 ether);
```

### 2. 取款
```solidity
// 取出0.5个以太币
bank.withdraw(0.5 ether);
```

### 3. 转账
```solidity
// 向其他用户转账0.3个以太币
bank.transfer(recipientAddress, 0.3 ether);
```

### 4. 查询余额
```solidity
// 查询自己的余额
uint256 myBalance = bank.getMyBalance();

// 查询其他用户的余额
uint256 userBalance = bank.getBalance(userAddress);

// 查询合约总余额
uint256 totalBalance = bank.getContractBalance();
```

## 部署和测试

### 编译合约
```bash
forge build
```

### 运行测试
```bash
# 运行所有Bank合约测试
forge test --match-contract BankTest -vv

# 运行特定测试
forge test --match-test testDeposit -vv
```

### 部署合约
```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key_here

# 部署到本地网络
forge script script/Bank.s.sol:BankScript --rpc-url http://localhost:8545 --broadcast

# 部署到测试网络（如Sepolia）
forge script script/Bank.s.sol:BankScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## 安全考虑

### 已实现的安全措施
1. **重入攻击防护**: 在转账前先更新状态
2. **权限控制**: 使用 `onlyOwner` 修饰符
3. **输入验证**: 检查金额、地址等参数
4. **溢出保护**: 使用 Solidity 0.8+ 的内置溢出检查

### 注意事项
1. 合约拥有者拥有紧急提取权限，请确保私钥安全
2. 在生产环境中使用前，建议进行专业的安全审计
3. 考虑添加暂停功能和升级机制

## Gas 消耗

基于测试结果的大致 Gas 消耗：
- 存款: ~47,000 gas
- 取款: ~58,000 gas
- 转账: ~78,000 gas
- 查询余额: ~2,000 gas（view函数）

## 许可证

MIT License