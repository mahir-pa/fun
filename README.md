# AmericanFootball.Fun 🏈  
Fantasy Football Packs & Marketplace powered by **Flare + XRPL**  

A decentralized fantasy sports platform where users open randomized NFT player packs and trade them on a live marketplace, using **FLR or FXRP tokens** for payments.  

---

## 🌍 Problem  

Fantasy football platforms today are:  
- **Centralized** → Users don’t truly own their cards; accounts can be frozen.  
- **Opaque** → Random pack draws and market pricing aren’t transparent.  
- **Single-chain limited** → Locked into one blockchain, limiting liquidity and interoperability.  

---

## 💡 Solution  

AmericanFootball.Fun uses **Flare smart contracts + XRPL token rails** to create a **provably fair, on-chain fantasy pack system** where:  
- Users open **Pro / Epic / Legendary packs** with transparent odds.  
- Player cards are minted as ERC-1155 NFTs, owned in the user’s wallet.  
- A **transfers marketplace** lets users trade cards using FLR or FXRP, with live market cap/volume charts.  
- The entire flow is **open source, modular, and upgradable**.  

---

## 🛠 Contract 1: `FantasyPacksStorage.sol`

### Purpose  
Acts as the **source of truth** for pack pricing and player metadata. Keeps contracts modular by separating state from logic.  

### Key Features  
- **Player Registry**:  
  - `addPlayer(uint256 playerId, string memory name, string memory team)`  
    → Admin-only function to register new players.  
  - `getPlayer(uint256 playerId)`  
    → Public read function to fetch player info.  

- **Pack Prices**:  
  - `setPackPrices(uint256 basic, uint256 epic, uint256 legendary)`  
    → Owner can adjust pack prices at runtime.  
  - Used by Logic contract to enforce payments.  

### Why a Separate Storage Contract?  
- Keeps data cleanly separated from execution.  
- Allows upgrades of the Logic contract without migrating data.  
- Optimized for **gas-efficiency and scalability**.  

---

## 🛠 Contract 2: `FantasyPacksNFT.sol`

### Purpose  
ERC-1155 NFT contract that actually mints the player cards when packs are opened.  

### Key Features  
- **Minting**:  
  - `mint(address to, uint256 id, uint256 amount)` → Creates player NFTs.  
- **Authorization**:  
  - `setPackLogicContract(address logic)` → Restricts minting to the trusted Logic contract.  
- **ERC-1155 Standard**:  
  - Supports multiple token IDs (different players) in a single contract.  

### Security  
- Users cannot mint directly — only the Logic contract can.  
- Prevents spoofed or fake NFTs from being generated.  
- Ownership transfers are handled via ERC-1155 standard.  

---

## 🛠 Contract 3: `FantasyPacksLogic.sol`

### Purpose  
The **engine** of the system — handles payments, randomization, and NFT minting.  

### Key Features  
- **Pack Purchase**:  
  - `buyAndOpenPack(uint8 packType) payable`  
    → User pays in FLR, Logic verifies correct price, and triggers pack open.  
- **Price Retrieval**:  
  - `getPrices()` → Returns pack prices from Storage for the frontend.  
- **Events**:  
  - `OpenedPack(address indexed user, uint8 packType, uint256 playerId, uint8 rolledTier)`  
    → Emitted whenever a pack is opened, so the frontend can animate the reveal.  

### Randomization Flow  
1. User selects pack type (Pro/Epic/Legendary).  
2. Contract applies weighted randomness:  
   - Pro packs → mostly common players.  
   - Epic packs → rare chance of Epic/Legendary.  
   - Legendary packs → highest chance for Legendary tier.  
3. A player ID is selected from the Storage registry.  
4. NFT contract mints the player card to the user.  

---

## 🔒 Security Design  

- **Strict Access Control**:  
  - Only Logic can mint NFTs.  
  - Only Owner can add players or adjust pack prices.  

- **Transparent Pack Opening**:  
  - Random results are on-chain, tied to transaction hash + block.  

- **Upgradeable Architecture**:  
  - New Logic contracts can be deployed and pointed to Storage + NFT, without reminting all data.  

- **Cross-chain Payments**:  
  - Frontend supports **FLR and FXRP** toggles, demoing Flare ↔ XRPL interoperability.  

---

## 🔗 Full System Flow  

1. **User Journey**  
   - Prelogin → Intro page  
   - Login → Wallet connection  
   - Postlogin → Dashboard with packs  
   - Transfers → Marketplace  

2. **Opening a Pack**  
   - User selects Pro/Epic/Legendary.  
   - Frontend calls `buyAndOpenPack()`.  
   - Logic fetches pack price from Storage.  
   - User pays with FLR (or demo toggle to FXRP).  
   - Player NFT minted via NFT contract.  
   - Frontend popup shows the player card:  
     - Pro → Alex Turner  
     - Epic → Alex Becker  
     - Legendary → Travis Kelce  

3. **Marketplace (Transfers)**  
   - Shows market cap/volume charts (D/W/M/Y).  
   - Lists 100 players with search/sort.  
   - Demo trade screen for Patrick Mahomes:  
     - Pay box (FLR/FXRP toggle).  
     - Receive box (player shares).  
     - Upcoming matches, performance, price history, radar stats chart.  

---

## 📸 Screenshots  
<img width="1470" height="841" alt="Screenshot 2025-09-21 at 11 45 24 AM" src="https://github.com/user-attachments/assets/7e1a8ccd-ba2f-4c32-b93d-453a1033fe06" />
<img width="1468" height="774" alt="Screenshot 2025-09-21 at 11 45 32 AM" src="https://github.com/user-attachments/assets/809b8759-a10c-49fd-9bfa-55ed43c9d4d1" />
<img width="1470" height="840" alt="Screenshot 2025-09-21 at 11 45 47 AM" src="https://github.com/user-attachments/assets/099b9338-6dd5-461b-9cd0-482dee55fd6e" />
<img width="1470" height="841" alt="Screenshot 2025-09-21 at 11 45 54 AM" src="https://github.com/user-attachments/assets/25394c02-7229-4695-ad38-eb181cd1d395" />
<img width="1470" height="837" alt="Screenshot 2025-09-21 at 11 46 01 AM" src="https://github.com/user-attachments/assets/8f7381b0-42d0-469a-9c34-6aafa2ccd7f7" />
<img width="1470" height="840" alt="Screenshot 2025-09-21 at 11 46 10 AM" src="https://github.com/user-attachments/assets/22b1e09f-84c2-46d3-a23d-37a5830c65b0" />
<img width="622" height="650" alt="Screenshot 2025-09-21 at 11 46 19 AM" src="https://github.com/user-attachments/assets/d95d1738-dff5-4d5a-b118-d47f6dd6873d" />
<img width="1269" height="304" alt="Screenshot 2025-09-21 at 11 46 24 AM" src="https://github.com/user-attachments/assets/3d5f6d97-5671-4de1-81bb-0e95f65f49bc" />

---

## 📽 Demo Video (to be added)  

[demovid](https://drive.google.com/file/d/1zqrkWmj_PibIq4e1iTgdvu7W5W32cL8c/view?usp=sharing)

---

## 🧑‍💻 Team  

Built by:
**Mahir Patel** @ Boston University (College of Engineering) 
**Pramay Jain** @ Boston University (Questrom)
Track: **Vibe Coding — Flare x XRPL Commons x EasyA Harvard Hackathon**  

---

## 🔗 Links  

- Repo: [https://github.com/mahir-pa/fun](https://github.com/mahir-pa/fun)  
- Live Demo: https://mahir-pa.github.io/fun/  
- Slides: [slides](https://www.canva.com/design/DAGzlrjcKVo/hJW7Rz5IRGpJ6xzy86stDQ/edit?utm_content=DAGzlrjcKVo&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton)  
