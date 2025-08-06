// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Bank
 * @dev 一个简单的银行合约，实现基本的存款、取款功能
 */
contract Bank {
    // 存储每个地址的余额
    mapping(address => uint256) private balances;
    
    // 合约拥有者
    address public owner;
    
    // 自动转移阈值
    uint256 public autoTransferThreshold;
    
    // 自动转移目标地址
    address public autoTransferTarget;
    
    // 是否启用自动转移
    bool public autoTransferEnabled;
    
    // 最小转移金额（防止频繁小额转移）
    uint256 public minimumTransferAmount;
    
    // 上次自动转移时间（防止过于频繁执行）
    uint256 public lastAutoTransferTime;
    
    // 自动转移冷却时间（秒）
    uint256 public autoTransferCooldown;
    
    // 事件定义
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event AutoTransfer(uint256 amount, address indexed to);
    event ThresholdUpdated(uint256 newThreshold);
    event AutoTransferTargetUpdated(address indexed newTarget);
    event AutoTransferToggled(bool enabled);
    event MinimumTransferAmountUpdated(uint256 newAmount);
    event AutoTransferCooldownUpdated(uint256 newCooldown);
    event AutoTransferSkipped(string reason, uint256 contractBalance);
    
    // 修饰符：只有拥有者可以调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    // 修饰符：检查余额是否足够
    modifier hasSufficientBalance(uint256 amount) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        _;
    }
    
    /**
     * @dev 构造函数，设置合约拥有者
     * @param _threshold 自动转移阈值
     * @param _target 自动转移目标地址
     */
    constructor(uint256 _threshold, address _target) {
        owner = msg.sender;
        autoTransferThreshold = _threshold;
        autoTransferTarget = _target;
        autoTransferEnabled = true;
        minimumTransferAmount = 0.01 ether; // 默认最小转移金额
        autoTransferCooldown = 0; // 默认无冷却时间，可通过setAutoTransferCooldown设置
        lastAutoTransferTime = 0;
    }
    
    /**
     * @dev 存款函数
     * 用户可以向合约存入以太币
     */
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
        
        // 检查是否需要自动转移
        _checkAndExecuteAutoTransfer();
    }
    
    /**
     * @dev 取款函数
     * 用户可以从合约中取出指定数量的以太币
     * @param amount 要取出的金额
     */
    function withdraw(uint256 amount) public hasSufficientBalance(amount) {
        require(amount > 0, "Withdraw amount must be greater than 0");
        
        // 先更新状态，防止重入攻击
        balances[msg.sender] -= amount;
        
        // 转账给用户
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdraw(msg.sender, amount);
    }
    
    /**
     * @dev 转账函数
     * 用户可以向其他地址转账
     * @param to 接收方地址
     * @param amount 转账金额
     */
    function transfer(address to, uint256 amount) public hasSufficientBalance(amount) {
        require(to != address(0), "Cannot transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than 0");
        require(to != msg.sender, "Cannot transfer to yourself");
        
        balances[msg.sender] -= amount;
        balances[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
    }
    
    /**
     * @dev 查询余额函数
     * @param user 要查询的地址
     * @return 该地址的余额
     */
    function getBalance(address user) public view returns (uint256) {
        return balances[user];
    }
    
    /**
     * @dev 查询自己的余额
     * @return 调用者的余额
     */
    function getMyBalance() public view returns (uint256) {
        return balances[msg.sender];
    }
    
    /**
     * @dev 查询合约总余额
     * @return 合约中的总以太币数量
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev 获取所有用户余额总和（用于一致性检查）
     * 注意：这个函数在实际应用中可能gas消耗很高，仅用于调试和测试
     * @param users 要检查的用户地址数组
     * @return totalUserBalances 用户余额总和
     */
    function getTotalUserBalances(address[] memory users) public view returns (uint256 totalUserBalances) {
        for (uint256 i = 0; i < users.length; i++) {
            totalUserBalances += balances[users[i]];
        }
    }
    
    /**
     * @dev 检查余额一致性
     * @param users 要检查的用户地址数组
     * @return isConsistent 余额是否一致
     * @return contractBalance 合约实际余额
     * @return userBalancesSum 用户余额总和
     */
    function checkBalanceConsistency(address[] memory users) public view returns (
        bool isConsistent,
        uint256 contractBalance,
        uint256 userBalancesSum
    ) {
        contractBalance = address(this).balance;
        userBalancesSum = getTotalUserBalances(users);
        isConsistent = userBalancesSum <= contractBalance;
    }
    
    /**
     * @dev 紧急提取函数（仅拥有者）
     * 拥有者可以提取合约中的所有资金
     */
    function emergencyWithdraw() public onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner).call{value: contractBalance}("");
        require(success, "Emergency withdraw failed");
    }
    
    /**
     * @dev 设置自动转移阈值（仅拥有者）
     * @param _threshold 新的阈值
     */
    function setAutoTransferThreshold(uint256 _threshold) public onlyOwner {
        autoTransferThreshold = _threshold;
        emit ThresholdUpdated(_threshold);
    }
    
    /**
     * @dev 设置自动转移目标地址（仅拥有者）
     * @param _target 新的目标地址
     */
    function setAutoTransferTarget(address _target) public onlyOwner {
        require(_target != address(0), "Target cannot be zero address");
        autoTransferTarget = _target;
        emit AutoTransferTargetUpdated(_target);
    }
    
    /**
     * @dev 切换自动转移功能（仅拥有者）
     * @param _enabled 是否启用
     */
    function toggleAutoTransfer(bool _enabled) public onlyOwner {
        autoTransferEnabled = _enabled;
        emit AutoTransferToggled(_enabled);
    }
    
    /**
     * @dev 设置最小转移金额（仅拥有者）
     * @param _amount 新的最小转移金额
     */
    function setMinimumTransferAmount(uint256 _amount) public onlyOwner {
        require(_amount > 0, "Minimum transfer amount must be greater than 0");
        minimumTransferAmount = _amount;
        emit MinimumTransferAmountUpdated(_amount);
    }
    
    /**
     * @dev 设置自动转移冷却时间（仅拥有者）
     * @param _cooldown 新的冷却时间（秒）
     */
    function setAutoTransferCooldown(uint256 _cooldown) public onlyOwner {
        require(_cooldown >= 60, "Cooldown must be at least 60 seconds");
        autoTransferCooldown = _cooldown;
        emit AutoTransferCooldownUpdated(_cooldown);
    }
    
    /**
     * @dev 手动触发自动转移检查（仅拥有者）
     */
    function manualAutoTransfer() public onlyOwner {
        _checkAndExecuteAutoTransfer();
    }
    
    /**
     * @dev 外部触发自动转移检查（用于自动化合约）
     */
    function triggerAutoTransfer() public {
        _checkAndExecuteAutoTransfer();
    }
    
    /**
     * @dev 内部函数：检查并执行自动转移
     */
    function _checkAndExecuteAutoTransfer() internal {
        if (!autoTransferEnabled || autoTransferTarget == address(0)) {
            emit AutoTransferSkipped("Auto transfer disabled or target not set", address(this).balance);
            return;
        }
        
        // 检查冷却时间（如果设置了冷却时间）
        if (autoTransferCooldown > 0 && block.timestamp < lastAutoTransferTime + autoTransferCooldown) {
            emit AutoTransferSkipped("Cooldown period not elapsed", address(this).balance);
            return;
        }
        
        uint256 contractBalance = address(this).balance;
        if (contractBalance < autoTransferThreshold) {
            emit AutoTransferSkipped("Balance below threshold", contractBalance);
            return;
        }
        
        uint256 transferAmount = contractBalance / 2;
        
        // 检查最小转移金额
        if (transferAmount < minimumTransferAmount) {
            emit AutoTransferSkipped("Transfer amount below minimum", contractBalance);
            return;
        }
        
        // 执行转移
        (bool success, ) = payable(autoTransferTarget).call{value: transferAmount}("");
        if (success) {
            lastAutoTransferTime = block.timestamp;
            emit AutoTransfer(transferAmount, autoTransferTarget);
        } else {
            emit AutoTransferSkipped("Transfer failed", contractBalance);
        }
    }
    
    /**
     * @dev 接收以太币的回退函数
     * 当有人直接向合约发送以太币时，自动调用deposit函数
     */
    receive() external payable {
        deposit();
    }
    
    /**
     * @dev 回退函数
     * 当调用不存在的函数时触发
     */
    fallback() external payable {
        deposit();
    }
}