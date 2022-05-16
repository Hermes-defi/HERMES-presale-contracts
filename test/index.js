const { expect } = require("chai");
const { ethers } = require("hardhat");

function fromWei(v){
  return ethers.utils.formatUnits(v,'ether').toString();
}
function fromGwei(v){
  return ethers.utils.formatUnits(v,'gwei').toString();
}

describe("Main", function () {
  it("presale whitelisted", async function () {

    const [DEV, TREASURE] = await ethers.getSigners();
    const dev = DEV.address;
    const treasure = TREASURE.address;

    const Main = await ethers.getContractFactory("Main");
    const Plutus = await ethers.getContractFactory("Plutus");
    const PreHermes = await ethers.getContractFactory("PreHermes");
    const Hermes = await ethers.getContractFactory("Hermes");

    const plutus = await Plutus.deploy();
    await plutus.deployed();

    const preHermes = await PreHermes.deploy(dev);
    await preHermes.deployed();

    const hermes = await Hermes.deploy();
    await hermes.deployed();

    const main = await Main.deploy(
        plutus.address, preHermes.address, hermes.address);
    await main.deployed();
    await main.adminChangeTreasure(treasure);



    const amount = '100000000000000000000';
    await plutus.approve(main.address, amount);
    await plutus.mint(dev, amount);
    const plutusBalanceOfDev = await plutus.balanceOf(dev);

    let preHermesBalance = (await preHermes.balanceOf(dev)).toString();
    let hermesBalance = (await hermes.balanceOf(dev)).toString();

    await preHermes.transfer(main.address, preHermesBalance);
    await hermes.mint(dev, preHermesBalance);
    await hermes.transfer(main.address, preHermesBalance);


    await main.adminSetWhitelist(dev, amount);

    await main.convertWhitelisted(amount);
    preHermesBalance = (await preHermes.balanceOf(dev)).toString();
    await preHermes.approve(main.address, preHermesBalance);
    await main.claim(preHermesBalance);
    hermesBalance = (await hermes.balanceOf(dev)).toString();
    const preHermesTreasure = (await preHermes.balanceOf(treasure)).toString();

    await plutus.approve(main.address, amount);
    await plutus.mint(dev, amount);
    await main.convertPublic(amount);

    console.log('PLTS amount:', fromWei(amount));
    console.log('plutusBalanceOfDev:', fromWei(plutusBalanceOfDev));
    console.log('preHermes balance:', fromGwei(preHermesBalance));
    console.log('hermes balance:', fromGwei(hermesBalance));
    console.log('preHermes Treasure balance:', fromGwei(preHermesTreasure));

  });
});
