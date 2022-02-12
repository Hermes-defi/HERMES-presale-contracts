const { ethers } = require('hardhat');
const { expect } = require('chai');


const PLUTUSADDRESS= "0xd32858211fcefd0be0dd3fd6d069c3e821e0aef3";

describe("Hermes", function () {
    let deployer, alice, bob, attacker;
    let users;
    beforeEach(async function () {
        console.log("before each");
        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();

        const HermesFactory = await ethers.getContractFactory("Hermes", deployer);
        const PlutusFactory = await ethers.getContractFactory("Plutus");

        plutus = await PlutusFactory.attach(PLUTUSADDRESS);

        await plutus.deployed();

        hermes = await HermesFactory.deploy(plutus.address, "HERMES", "HRMS");
        await hermes.deployed();

        await plutus.connect(deployer).transfer(alice.address, "5");

        const myPlutusBalance = await plutus.balanceOf(deployer.address);
        console.log("my plts", myPlutusBalance);
    });
    describe("when user deposits", () => {


        it("can deposit", async () => {
            const alicePltsBalance = (await plutus.balanceOf(alice.address)).toString();
            expect(alicePltsBalance).to.be.equal("5");
            await plutus.connect(alice).approve(hermes.address, alicePltsBalance);
            await hermes.connect(alice).deposit(alicePltsBalance);
            const aliceHrmsBalance = (await hermes.balanceOf(alice.address)).toString();
            const newAlicePltsBalance = (await plutus.balanceOf(alice.address)).toString();

            expect(aliceHrmsBalance).to.be.equal("5");
            expect(newAlicePltsBalance).to.be.equal("0");
        });
    });
});