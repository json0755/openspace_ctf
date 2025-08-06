# Bank 智能合约项目

这是一个完整的去中心化银行智能合约项目，支持基础的存取款功能以及自动化资金转移功能。

## 项目概述

本项目包含两个主要合约：

1. **Bank.sol** - 核心银行合约，提供存款、取款、转账等基础功能
2. **BankAutomation.sol** - 自动化合约，与 ChainLink Automation 兼容，实现自动资金转移

## 核心功能

### Bank 合约功能

#### 基础银行功能
- 💰 **存款**: 用户可以向合约存入以太币
- 💸 **取款**: 用户可以取出自己的资金
- 🔄 **转账**: 用户之间可以进行内部转账
- 📊 **余额查询**: 查询个人或合约总余额

#### 自动转移功能
- 🎯 **阈值监控**: 当合约余额超过设定阈值时自动触发转移
- ⚡ **自动转移**: 自动将一半资金转移到指定地址
- 🔧 **灵活配置**: 支持动态调整阈值、目标地址和开关状态
- 🛡️ **安全控制**: 只有合约拥有者可以修改配置

#### 安全特性
- 🔒 **重入攻击防护**: 使用 Checks-Effects-Interactions 模式
- 👑 **权限控制**: 关键功能仅限合约拥有者
- ✅ **输入验证**: 严格的参数验证和边界检查
- 📝 **事件记录**: 完整的操作日志记录

### BankAutomation 合约功能

#### ChainLink Automation 兼容
- 🤖 **自动监控**: 定期检查 Bank 合约状态
- ⏰ **时间控制**: 可配置的检查间隔
- 🎯 **条件触发**: 满足条件时自动执行转移
- 📊 **状态报告**: 提供详细的执行状态信息

## 技术架构

### 合约结构
```
├── src/
│   ├── Bank.sol              # 核心银行合约
│   └── BankAutomation.sol     # 自动化监控合约
├── test/
│   ├── Bank.t.sol            # Bank 合约测试
│   └── BankAutomation.t.sol   # 自动化合约测试
└── script/
    └── Bank.s.sol            # 部署脚本
```

### 主要接口

#### Bank 合约
```solidity
// 基础功能
function deposit() public payable
function withdraw(uint256 amount) public
function transfer(address to, uint256 amount) public

// 查询功能
function getBalance(address user) public view returns (uint256)
function getContractBalance() public view returns (uint256)

// 管理功能（仅拥有者）
function setAutoTransferThreshold(uint256 _threshold) public onlyOwner
function setAutoTransferTarget(address _target) public onlyOwner
function toggleAutoTransfer(bool _enabled) public onlyOwner

// 自动化接口
function triggerAutoTransfer() public
```

#### BankAutomation 合约
```solidity
// ChainLink Automation 接口
function checkUpkeep(bytes calldata checkData) external view returns (bool, bytes memory)
function performUpkeep(bytes calldata performData) external

// 管理功能
function setInterval(uint256 _interval) external onlyOwner
function manualUpkeep() external onlyOwner

// 查询功能
function getBankInfo() external view returns (uint256, uint256, bool, address)
```

## 部署和使用

### 环境要求
- Foundry 开发框架
- Solidity ^0.8.0
- Node.js (可选，用于前端集成)

### 快速开始

1. **克隆项目**
```bash
git clone <repository-url>
cd openspace_ctf
```

2. **安装依赖**
```bash
forge install
```

3. **运行测试**
```bash
forge test
```

4. **编译合约**
```bash
forge build
```

5. **部署合约**
```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key
export AUTO_TRANSFER_THRESHOLD=5000000000000000000  # 5 ETH
export AUTO_TRANSFER_TARGET=0x...
export AUTOMATION_INTERVAL=300  # 5分钟

# 部署到本地网络
forge script script/Bank.s.sol --rpc-url http://localhost:8545 --broadcast

# 部署到测试网
forge script script/Bank.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

### ChainLink Automation 设置

#### 重要说明
合约中的 `interval` 参数**不是**ChainLink Automation的执行频率！ <mcreference link="https://docs.chain.link/chainlink-automation/guides/compatible-contracts" index="1">1</mcreference>
- **实际执行频率**: 在ChainLink Automation平台上配置
- **合约interval**: 仅作为额外保护机制，防止执行过于频繁

#### 配置步骤

1. **注册 Upkeep**
   - 访问 [ChainLink Automation](https://automation.chain.link/)
   - 选择 "Custom Logic" 触发类型 <mcreference link="https://docs.chain.link/chainlink-automation/guides/compatible-contracts" index="1">1</mcreference>
   - 使用 BankAutomation 合约地址注册新的 Upkeep
   - 设置适当的资金和执行参数

2. **平台配置参数**
   - **Gas Limit**: 建议 500,000
   - **Check Data**: 留空
   - **执行频率**: 在平台上设置（如每5分钟检查一次）
   - **触发条件**: Custom Logic

3. **合约配置参数**
   - **interval**: 设置最小执行间隔（如300秒），作为额外保护
   - **threshold**: 在Bank合约中设置自动转移阈值
   - **target**: 设置转移目标地址

4. **监控执行**
   - 通过 ChainLink 仪表板监控执行状态
   - 查看合约事件日志确认转移操作
   - 监控LINK余额确保有足够资金支付Gas费用

## 测试覆盖

项目包含全面的测试套件：

### Bank 合约测试 (23个测试用例)
- ✅ 基础功能测试（存款、取款、转账）
- ✅ 边界条件测试（零金额、余额不足等）
- ✅ 权限控制测试
- ✅ 自动转移功能测试
- ✅ 事件触发测试
- ✅ 安全性测试

### BankAutomation 合约测试 (15个测试用例)
- ✅ ChainLink Automation 接口测试
- ✅ 条件检查逻辑测试
- ✅ 执行流程测试
- ✅ 权限控制测试
- ✅ 配置管理测试
- ✅ 事件记录测试

## 安全考虑

### 已实现的安全措施
- 🔒 **重入攻击防护**: 状态更新在外部调用之前
- 🛡️ **权限控制**: 关键功能限制访问
- ✅ **输入验证**: 严格的参数检查
- 📝 **事件日志**: 完整的操作记录
- 🔍 **溢出保护**: 使用 Solidity 0.8+ 内置保护

### 建议的额外措施
- 考虑添加多重签名控制
- 实施时间锁定机制
- 定期安全审计
- 监控异常活动

## Gas 优化

合约已进行 Gas 优化：
- 使用 `immutable` 变量减少存储读取
- 优化循环和条件判断
- 合理使用事件记录
- 避免不必要的存储操作

## 许可证

MIT License - 详见 LICENSE 文件

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

如有问题或建议，请通过以下方式联系：
- GitHub Issues
- 项目维护者邮箱

---

**注意**: 这是一个演示项目，在生产环境中使用前请进行充分的安全审计。