import { ethers } from "ethers";
import * as dotenv from "dotenv";
import { Token__factory, Ethay__factory, Sender__factory, Receiver__factory } from "../typechain-types";

dotenv.config();

// Contract addresses - Replace with your deployed contract addresses
const CONTRACTS = {
  BASE_TESTNET: {
    USDT: '0x28aD5A6F6592Eaa2DaAf6d01c5Bcf71E0092dAf4',
    ETHAY: '0xEA16f419A88E9d2b7425e5C611bf15116af1A4C1',
    RECEIVER: '0x572832c0Ce02F5e063963a2a6af972B1Fd61C8cD',
  },
  SEPOLIA: {
    USDT: '0x28aD5A6F6592Eaa2DaAf6d01c5Bcf71E0092dAf4',
    SENDER: '0xD5c1A8122066dD0aCD3c82C39527B5380242fC44',
  },
}

// Chain configuration
const CHAIN_CONFIG = {
  BASE_TESTNET: {
    rpc: 'https://base-sepolia.blockpi.network/v1/rpc/public',
    chainId: 84531,
  },
  SEPOLIA: {
    rpc: 'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
    chainId: 11155111,
  },
}

async function main() {
  // Setup providers and wallets
  const baseProvider = new ethers.JsonRpcProvider(CHAIN_CONFIG.BASE_TESTNET.rpc);
  const sepoliaProvider = new ethers.JsonRpcProvider(CHAIN_CONFIG.SEPOLIA.rpc);

  // Setup wallets using private keys
  const seller = new ethers.Wallet(process.env.SELLER_PRIVATE_KEY!, baseProvider);
  const buyer = new ethers.Wallet(process.env.BUYER_PRIVATE_KEY!, baseProvider);
  const judge = new ethers.Wallet(process.env.JUDGE_PRIVATE_KEY!, baseProvider);
  const buyerSepolia = new ethers.Wallet(
    process.env.BUYER_PRIVATE_KEY!,
    sepoliaProvider
  )

  // Contract instances on Base Testnet
  const baseUsdt = Token__factory.connect(CONTRACTS.BASE_TESTNET.USDT, baseProvider);
  const ethay = Ethay__factory.connect(CONTRACTS.BASE_TESTNET.ETHAY, baseProvider);
  
  // Contract instances on Sepolia
  const sepoliaUsdt = Token__factory.connect(CONTRACTS.SEPOLIA.USDT, sepoliaProvider);
  const sender = Sender__factory.connect(CONTRACTS.SEPOLIA.SENDER, sepoliaProvider);

  console.log("Starting e-commerce flow...");

  try {
    // 1. Register seller and create product
    // console.log("Registering seller...");
    // const registerTx = await ethay.connect(seller).registerAsSeller();
    // await registerTx.wait();
    // console.log("Seller registered");

    // const createProductTx = await ethay.connect(seller).createProduct(
    //   "Test Product",
    //   ethers.parseUnits("100", 18), // 100 USDT
    //   100, // quantity
    //   "ipfs://test",
    //   "Test Description"
    // );
    // await createProductTx.wait();
    // console.log("Product created: "+createProductTx.hash);

    // 2. Buyer mints USDT and buys product
    // console.log("Minting USDT for buyer...");
    // const mintTx = await baseUsdt.connect(buyer).mint(
    //   buyer.address,
    //   ethers.parseUnits("100", 18)
    // );
    // await mintTx.wait();
    // console.log("USDT minted: "+mintTx.hash);

    // console.log("Approving USDT...");
    // const approveTx = await baseUsdt.connect(buyer).approve(
    //   CONTRACTS.BASE_TESTNET.ETHAY,
    //   ethers.parseUnits("100", 18)
    // );
    // await approveTx.wait();
    // console.log("USDT approved: "+approveTx.hash);

    // console.log("Buying product...");
    // const buyTx = await ethay.connect(buyer).buyProduct(
    //   buyer.address,
    //   0, // product ID
    //   1, // quantity
    //   ethers.ZeroAddress // no referrer
    // );
    // await buyTx.wait();
    // console.log("Product bought: "+buyTx.hash);

    // 3. Confirm purchase
    // console.log("Confirming purchase...");
    // const confirmTx = await ethay.connect(buyer).confirmPurchase(0, 0);
    // await confirmTx.wait();
    // console.log("Purchase confirmed: "+confirmTx.hash);
 
    // 4. Register judge
    // console.log("Registering judge...");
    // const registerJudgeTx = await ethay.connect(judge).registerAsJudge();
    // await registerJudgeTx.wait();
    // console.log("Judge registered: "+registerJudgeTx.hash);

    // 5. Raise dispute
    // console.log("Raising dispute...");
    // const disputeTx = await ethay.connect(buyer).raiseDispute(0, 1, {
    //   value: ethers.parseEther('0.005'), // Fee for entropy
    // })
    // await disputeTx.wait();
    // console.log("Dispute raised: "+disputeTx.hash);

    // 6. Resolve dispute
    console.log("Resolving dispute...");
    const resolveTx = await ethay.connect(judge).resolveDispute(
      0,
      1,
      ethers.parseUnits("50", 18) // 50 USDT to buyer
    );
    await resolveTx.wait();

    // 7. Cross-chain purchase on Sepolia
    console.log("Starting cross-chain purchase...");
    
    // Mint USDT on Sepolia
    const mintSepoliaTx = await sepoliaUsdt.connect(buyerSepolia).mint(
      buyerSepolia.address,
      ethers.parseUnits("10000", 18)
    );
    await mintSepoliaTx.wait();
    console.log("USDT minted on Sepolia: "+mintSepoliaTx.hash);
    // Approve USDT for Sender contract
    const approveSepoliaTx = await sepoliaUsdt.connect(buyerSepolia).approve(
      CONTRACTS.SEPOLIA.SENDER,
      ethers.parseUnits("10000", 18)
    );
    await approveSepoliaTx.wait();
    console.log("USDT approved on Sepolia: "+approveSepoliaTx.hash);

    // Send cross-chain message
    const sendMessageTx = await sender.connect(buyerSepolia).sendMessage(
      '10344971235874465080', // Base testnet chain selector
      CONTRACTS.BASE_TESTNET.RECEIVER, // receiver address
      buyerSepolia.address, // buyer
      0, // product ID
      1, // quantity
      ethers.ZeroAddress, // no referrer
      ethers.parseUnits('100', 18) // price
    )
    await sendMessageTx.wait();
    console.log("Cross-chain purchase completed: "+sendMessageTx.hash);
    console.log("Cross-chain purchase completed!");

  } catch (error) {
    console.error("Error:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 