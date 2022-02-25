// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const path = require("path");
const csv = require('csvtojson');

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  var absolutePath = path.resolve("./scripts/addresses-merged.csv");


  let currentBlock;
  const [deployer] = await ethers.getSigners();
  const PLUTUS_ADDRESS = "0xd32858211fcefd0be0dd3fd6d069c3e821e0aef3";

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
  const Plutus = await hre.ethers.getContractFactory("MockERC20");
  const PreHermes = await hre.ethers.getContractFactory("PreHermes");
  const Hermes = await hre.ethers.getContractFactory("Hermes");
  const L3PltsSwapBank = await hre.ethers.getContractFactory("L3PltsSwapBank");
  const L3PltsSwapGen = await hre.ethers.getContractFactory("L3PltsSwapGen");
  const L3HermesTokenRedeem = await hre.ethers.getContractFactory("L3HermesTokenRedeem");

  const plutus = await Plutus.attach(PLUTUS_ADDRESS);
  const pHermes = await PreHermes.deploy();
  const hermes = await Hermes.deploy();

  await pHermes.deployed();
  await hermes.deployed();
  console.log("plutus deployed to:", plutus.address);
  console.log("pHermes deployed to:", pHermes.address);
  console.log("Hermes deployed to:", hermes.address);

  currentBlock = await hre.ethers.provider.getBlockNumber() + 2;
  const l3PltsSwapBank = await L3PltsSwapBank.deploy(currentBlock, PLUTUS_ADDRESS, pHermes.address);
  await l3PltsSwapBank.deployed();
  console.log("l3PltsSwapBank deployed to:", l3PltsSwapBank.address);

  currentBlock = await hre.ethers.provider.getBlockNumber() + 2;
  const l3PltsSwapGen = await L3PltsSwapGen.deploy(currentBlock, PLUTUS_ADDRESS, pHermes.address);
  await l3PltsSwapGen.deployed();
  console.log("l3PltsSwapGen deployed to:", l3PltsSwapGen.address);

  currentBlock = await hre.ethers.provider.getBlockNumber() + 2;
  const l3HermesTokenRedeem = await L3HermesTokenRedeem.deploy(currentBlock, l3PltsSwapBank.address, l3PltsSwapGen.address, pHermes.address, hermes.address);
  await l3HermesTokenRedeem.deployed();
  console.log("l3HermesTokenRedeem deployed to:", l3HermesTokenRedeem.address);

  // whitelist users

  for (var i = 0; i < jason.length; i++) {

    var obj = jason[i];
    await l3PltsSwapBank.whitelistUser(obj["address"], hre.ethers.utils.parseEther(obj["amount"]));

  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
