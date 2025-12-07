// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FastDiceGame is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Base Configuration
    IERC20 public immutable usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    uint256 public constant PRIZE_AMOUNT = 10000; // 0.01 USDC (6 decimals)
    uint256 public constant MAX_NUMBER = 6;
    uint256 public constant PLAY_COOLDOWN = 10; // 10-second cooldown
    uint256 public constant MAX_PRIZE_POOL = 1000 * 1e6; // 1000 USDC max pool

    // Game State
    mapping(address => uint256) public lastPlayTime;
    uint256 private nonce;
    bool public paused;
    uint256 public totalGames;
    uint256 public totalWins;

    // Modifiers (defined before use)
    modifier whenNotPaused() {
        require(!paused, "Game paused");
        _;
    }

    // Events
    event GamePlayed(address indexed player, uint256 chosenNumber, uint256 rolledNumber, bool won);
    event PrizeClaimed(address indexed player, uint256 amount);
    event FundsDeposited(address indexed depositor, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event Paused(address indexed account, bool isPaused);

    constructor() Ownable(msg.sender) {
        require(address(usdc) != address(0), "Invalid USDC address");
    }

    /**
     * @dev Play the dice game (1-6)
     * @param chosenNumber Player's chosen number (1-6)
     */
    function play(uint256 chosenNumber) external nonReentrant whenNotPaused {
        require(chosenNumber >= 1 && chosenNumber <= MAX_NUMBER, "Number must be 1-6");
        require(block.timestamp >= lastPlayTime[msg.sender] + PLAY_COOLDOWN, "Wait 10 seconds");
        require(usdc.balanceOf(address(this)) >= PRIZE_AMOUNT, "Insufficient funds");
        require(usdc.balanceOf(address(this)) <= MAX_PRIZE_POOL, "Prize pool too large");

        // Generate pseudo-random number with multiple entropy sources
        uint256 rolledNumber = (uint256(keccak256(abi.encodePacked(
            block.prevrandao,
            block.timestamp,
            msg.sender,
            nonce++,
            block.chainid,
            address(this).balance
        ))) % MAX_NUMBER) + 1;

        bool won = (rolledNumber == chosenNumber);
        lastPlayTime[msg.sender] = block.timestamp;
        totalGames++;

        emit GamePlayed(msg.sender, chosenNumber, rolledNumber, won);

        if (won) {
            usdc.safeTransfer(msg.sender, PRIZE_AMOUNT);
            totalWins++;
            emit PrizeClaimed(msg.sender, PRIZE_AMOUNT);
        }
    }

    /**
     * @dev Deposit USDC to fund prizes
     * @param amount USDC amount to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(usdc.balanceOf(address(this)) + amount <= MAX_PRIZE_POOL, "Max pool exceeded");
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        emit FundsDeposited(msg.sender, amount);
    }

    /**
     * @dev Withdraw USDC (owner only)
     * @param amount USDC amount to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(usdc.balanceOf(address(this)) >= amount, "Insufficient balance");
        usdc.safeTransfer(owner(), amount);
        emit FundsWithdrawn(owner(), amount);
    }

    /**
     * @dev Emergency withdraw all USDC (owner only)
     */
    function emergencyWithdraw() external nonReentrant onlyOwner {
        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "No funds");
        usdc.safeTransfer(owner(), balance);
        emit FundsWithdrawn(owner(), balance);
    }

    /**
     * @dev Pause/unpause the game (owner only)
     * @param _paused Pause state
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(msg.sender, _paused);
    }

    /**
     * @dev Check remaining cooldown time for a player
     * @param player Address to check
     * @return Time until player can play again
     */
    function getCooldown(address player) external view returns (uint256) {
        uint256 lastPlay = lastPlayTime[player];
        return lastPlay + PLAY_COOLDOWN > block.timestamp ?
            lastPlay + PLAY_COOLDOWN - block.timestamp :
            0;
    }

    // View functions
    function getContractBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function getAvailablePrizes() external view returns (uint256) {
        return usdc.balanceOf(address(this)) / PRIZE_AMOUNT;
    }

    function getGameStats() external view returns (uint256 games, uint256 wins, uint256 winRate) {
        return (totalGames, totalWins, totalGames > 0 ? (totalWins * 100) / totalGames : 0);
    }
}
