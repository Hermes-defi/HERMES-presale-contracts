// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const path = require("path");
const csv = require('csvtojson');

async function main() {


  var absolutePath = path.resolve("./scripts/addresses-merged.csv");


  let currentBlock;
  const [deployer] = await ethers.getSigners();
  const ADMIN_ADDRESS = "0x1109c5BB8Abb99Ca3BBeff6E60F5d3794f4e0473"; // admin address on harmony mainnet
  const L3PLTSSWAPBANK_PHERMES_BALANCE = ethers.utils.parseEther('966930');
  const TOKENREDEEM_HERMES_SUPPLY = ethers.utils.parseEther('1800000'); // ~1.8M tokens

  // read data from file.
  const jason = await csv({
    noheader: true,
    headers: ['address', 'amount', 'ratio', 'timestamp']
  })
    .fromFile(absolutePath);

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  console.log("block number:", await hre.ethers.provider.getBlockNumber());

  // We get the contract to deploy
  const Plutus = await hre.ethers.getContractFactory("Plutus");
  const PreHermes = await hre.ethers.getContractFactory("PreHermes");
  const Hermes = await hre.ethers.getContractFactory("Hermes");
  const L3PltsSwapBank = await hre.ethers.getContractFactory("L3PltsSwapBank");
  const L3PltsSwapGen = await hre.ethers.getContractFactory("L3PltsSwapGen");
  const L3HermesTokenRedeem = await hre.ethers.getContractFactory("L3HermesTokenRedeem");

  // deploy tokens

  const plutus = await Plutus.deploy();
  const pHermes = await PreHermes.deploy(deployer.address);
  const hermes = await Hermes.deploy();

  await pHermes.deployed();
  await hermes.deployed();
  console.log("plutus deployed to:", plutus.address);
  console.log("pHermes deployed to:", pHermes.address);
  console.log("Hermes deployed to:", hermes.address);

  // deploy contracts

  currentBlock = await hre.ethers.provider.getBlockNumber() + 200; // set start block to the second next block
  const l3PltsSwapBank = await L3PltsSwapBank.deploy(currentBlock, plutus.address, pHermes.address);
  await l3PltsSwapBank.deployed();
  console.log("l3PltsSwapBank deployed to:", l3PltsSwapBank.address);

  currentBlock = await hre.ethers.provider.getBlockNumber() + 200; // set start block to the second next block
  const l3PltsSwapGen = await L3PltsSwapGen.deploy(currentBlock, plutus.address, pHermes.address);
  await l3PltsSwapGen.deployed();
  console.log("l3PltsSwapGen deployed to:", l3PltsSwapGen.address);

  currentBlock = await hre.ethers.provider.getBlockNumber() + 200; // set start block to the second next block
  const l3HermesTokenRedeem = await L3HermesTokenRedeem.deploy(currentBlock, l3PltsSwapBank.address, l3PltsSwapGen.address, pHermes.address, hermes.address);
  await l3HermesTokenRedeem.deployed();
  console.log("l3HermesTokenRedeem deployed to:", l3HermesTokenRedeem.address);

  // whitelist users

  for (var i = 0; i < jason.length; i++) {

    var obj = jason[i];
    await l3PltsSwapBank.whitelistUser(obj["address"], hre.ethers.utils.parseEther(obj["amount"]));
    console.log('added userInfo', i);

  }


  // transfer pHERMES to l3PlutusSwapBank
  console.log("phermes total suply", await pHermes.totalSupply());
  await pHermes.transfer(l3PltsSwapBank.address, L3PLTSSWAPBANK_PHERMES_BALANCE);
  console.log("l3PltsSwapBank phermes amount:", await pHermes.balanceOf(l3PltsSwapBank.address))

  // transfer pHERMES to l3PlutusSwapGen
  const amountToSend = await pHermes.balanceOf(deployer.address);
  await pHermes.transfer(l3PltsSwapGen.address, amountToSend);
  console.log("l3PltsSwapGen phermes amount:", await pHermes.balanceOf(l3PltsSwapGen.address))

  // mint HERMES to L3HermesTokenRedeem
  await hermes.mint(l3HermesTokenRedeem.address, TOKENREDEEM_HERMES_SUPPLY)
  console.log("tokenRedeem HERMES balance", await hermes.balanceOf(l3HermesTokenRedeem.address))

  // add l3PlutusSwapBank & l3PlutusSwapGen to plutus whitelist

  // transfer ownership after deployment
  await plutus.transferOwnership(ADMIN_ADDRESS);
  await pHermes.transferOwnership(ADMIN_ADDRESS);
  await hermes.transferOwnership(ADMIN_ADDRESS);
  await l3PltsSwapBank.transferOwnership(ADMIN_ADDRESS);
  await l3PltsSwapGen.transferOwnership(ADMIN_ADDRESS);
  await l3HermesTokenRedeem.transferOwnership(ADMIN_ADDRESS);


  console.log("phermes owner", await pHermes.owner())
  console.log("hermes owner", await hermes.owner())
  console.log("l3PltsSwapBank owner", await l3PltsSwapBank.owner())
  console.log("l3PltsSwapGen owner", await l3PltsSwapGen.owner())
  console.log("l3HermesTokenRedeem owner", await l3HermesTokenRedeem.owner())
  console.log("admin addr:", ADMIN_ADDRESS)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
