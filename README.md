
-----

````markdown
# 🎲 Fast Dice Game (Base Mainnet)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Network](https://img.shields.io/badge/network-Base_Mainnet-blue)
![Platform](https://img.shields.io/badge/platform-Farcaster%20%7C%20Web-purple)

A lightweight, decentralized dice gambling game built specifically for the **Farcaster** ecosystem on the **Base L2** network. Users pick a number (1-6), roll the dice on-chain, and receive instant USDC payouts if they win.

## ✨ Features

* **Farcaster Native:** Fully integrated with the Farcaster Mini-app SDK for seamless in-frame usage.
* **Dual Wallet Support:** Automatically detects Farcaster's injected wallet, falling back to MetaMask/EIP-1193 providers for standard web browsers.
* **Instant Settlement:** Payouts are processed in the same transaction as the roll.
* **Spam Protection:** Implements a cooldown timer (default: 10s) per address.
* **Resilient RPC:** Frontend cycles through multiple public RPC endpoints to ensure uptime.
* **No Build Step:** Frontend runs on pure HTML/JS via CDNs (Ethers.js + Tailwind).

---

## 🏗 Architecture

### Smart Contract (`FastDiceGame.sol`)
The contract is an `Ownable` system that holds a USDC balance.
* **Network:** Base Mainnet
* **Token:** USDC (`0x8335...`)
* **Randomness:** Pseudo-randomness based on `prevrandao` and `timestamp` (Suitable for low-stakes, fast-paced games).
* **Safety:** Uses OpenZeppelin's `SafeERC20` and `ReentrancyGuard`.

### Frontend (`index.html`)
A single-page application designed for speed.
* **Styling:** Tailwind CSS (via CDN).
* **Logic:** Ethers.js v5.7.2.
* **Integration:** Farcaster Miniapp SDK.

---

## 🚀 Getting Started

### Prerequisites
* Node.js (for contract deployment via Hardhat/Foundry)
* An EVM wallet with some ETH on Base for gas.
* USDC on Base for funding the prize pool.

### 1. Deploy Smart Contract

1.  Use Remix, Hardhat, or Foundry to deploy `FastDiceGame.sol`.
2.  **Verify** the contract on BaseScan.
3.  **Fund** the contract: Send USDC to the contract address to create the prize pool.
    * *Note: Ensure the contract balance does not exceed `MAX_PRIZE_POOL` defined in the solidity file.*

### 2. Configure Frontend

Open `index.html` and update the configuration section at the bottom of the script:

```javascript
// Contract Configuration
const CONTRACT_ADDRESS = "YOUR_DEPLOYED_CONTRACT_ADDRESS_HERE";
const BASE_MAINNET_CHAIN_ID = 8453;
````

### 3\. Run Locally

Since the frontend uses CDNs, you don't need `npm install`. You can use any static server.

```bash
# Using python
python3 -m http.server 8000

# OR using npx serve
npx serve .
```

Navigate to `http://localhost:8000` to test.

### 4\. Deployment

  * **Vercel/Netlify:** Simply upload `index.html`.
  * **Farcaster:** Submit the deployed URL as a Frame or Mini-app in Warpcast Developer settings.

-----

## 🎲 Game Mechanics & Logic

1.  **Connect:** User connects via Farcaster or MetaMask.
2.  **Select:** User chooses a number between 1 and 6.
3.  **Approve:** (If betting is enabled) User approves USDC spend.
4.  **Roll:** User sends a transaction to the `play()` function.
5.  **Result:**
      * **Win:** Contract immediately transfers `PRIZE_AMOUNT` to the user.
      * **Loss:** No transfer occurs.
6.  **Cooldown:** User must wait `PLAY_COOLDOWN` seconds before rolling again.

### Entropy Generation Logic

The core logic resides in the `play` function. Randomness is derived deterministically from the execution environment state at the moment of the transaction. This approach is optimized for high-throughput, low-stakes interactions.

**Source Code Implementation:**

```solidity
uint256 rolledNumber = (uint256(keccak256(abi.encodePacked(
    block.prevrandao,      // EVM Randomness Beacon
    block.timestamp,       // Block timestamp
    msg.sender,            // Player address
    nonce++,               // Internal state counter
    block.chainid,         // Network ID
    address(this).balance  // Contract ETH balance
))) % MAX_NUMBER) + 1;
```

### Atomic Settlement

The contract utilizes an "Instant Settlement" model. There is no separation between "Winning" and "Claiming."

  * **Logic:** If `rolledNumber == chosenNumber`, the contract executes a `SafeERC20` transfer immediately within the same transaction.
  * **Failure Mode:** If the contract holds insufficient USDC (`balance < PRIZE_AMOUNT`), the transaction reverts, protecting the user from paying gas for a game that cannot payout.

### Economic Controls

To mitigate risk and spam, the contract enforces the following constraints:

  * **Cooldown:** `block.timestamp` is compared against a mapping `lastPlayTime[msg.sender]`. A 10-second delta is enforced.
  * **Prize Cap:** The contract rejects deposits if the Total Value Locked (TVL) exceeds `MAX_PRIZE_POOL` (1000 USDC), limiting the exposure of funds in the hot wallet.

-----

## 🔌 Integration Interface

Developers and Indexers should use the following interface definitions:

### External Functions

```solidity
interface IFastDiceGame {
    // Execution
    function play(uint256 chosenNumber) external; 
    
    // Management
    function deposit(uint256 amount) external;
    
    // Read-Only Views
    function getCooldown(address player) external view returns (uint256);
    function getContractBalance() external view returns (uint256);
    function getGameStats() external view returns (uint256 games, uint256 wins, uint256 winRate);
}
```

### Events

The protocol emits the following events for off-chain indexing:

```solidity
// Emitted on every valid execution
event GamePlayed(address indexed player, uint256 chosenNumber, uint256 rolledNumber, bool won);

// Emitted only on winning outcomes
event PrizeClaimed(address indexed player, uint256 amount);

// Liquidity Events
event FundsDeposited(address indexed depositor, uint256 amount);
event FundsWithdrawn(address indexed owner, uint256 amount);
```

### Frontend Integration (Ethers.js Example)

```javascript
const contract = new ethers.Contract(ADDRESS, ABI, signer);

// Check Cooldown
const cooldown = await contract.getCooldown(userAddress);
if (cooldown > 0) throw new Error("Cooldown active");

// Execute Transaction
const tx = await contract.play(selectedNumber);
const receipt = await tx.wait();

// Parse Log for Result
const event = receipt.events.find(e => e.event === 'GamePlayed');
const [player, chosen, rolled, won] = event.args;
```

-----

## 🔒 Security Considerations

  * **Reentrancy:** The `play` function is protected by OpenZeppelin's `nonReentrant` modifier.
  * **Access Control:** Critical liquidity functions (`withdraw`, `emergencyWithdraw`) are restricted via `Ownable`.
  * **Token Safety:** All ERC-20 interactions use the `SafeERC20` library to handle non-standard return values from token contracts.
  * **Randomness Disclaimer:** This contract uses on-chain pseudo-randomness (`block.prevrandao`, `block.timestamp`). While sufficient for low-value casual games, **this is not secure for high-stakes gambling** as validators can theoretically manipulate block parameters.

-----

## 🔗 Links

  * **Live Miniapp:** [Farcaster Miniapp](https://farcaster.xyz/miniapps/jngLyEwfMIWu/fastdice)
  * **Developer:** [Naitik Rahane](https://farcaster.xyz/naitikrahane)

-----

## 🤝 Contributing

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

## 📁 Repo Structure

```text
my-dice-game-repo/
├── contracts/
│   └── DiceGame.sol       # The Solidity file
├── index.html                 # The HTML file            
├── README.md                  # This file
└── LICENSE                    # MIT License file
```

```
```
