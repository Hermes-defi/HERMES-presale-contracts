const { ethers } = require('hardhat');
const { expect, assert } = require('chai');
const { utils } = require('ethers');


function toWei(v) {
    return utils.parseUnits(v, 18).toString();
}

const PLUTUSADDRESS = "0xd32858211fcefd0be0dd3fd6d069c3e821e0aef3";

describe("Hermes", function () {
    let deployer, alice, bob, attacker;
    let users;
    beforeEach("Deploy contracts", async function () {

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();

        const HermesFactory = await ethers.getContractFactory("Hermes", deployer);
        const PlutusFactory = await ethers.getContractFactory("Plutus");

        plutus = await PlutusFactory.attach(PLUTUSADDRESS);

        await plutus.deployed();

        hermes = await HermesFactory.deploy(plutus.address, "HERMES", "HRMS");
        await hermes.deployed();

        await plutus.connect(deployer).transfer(alice.address, "5");

        const myPlutusBalance = await plutus.balanceOf(deployer.address);

        assert.equal((await hermes.cap()).toString(), toWei('30000000'));
    });
    describe("when user deposits", () => {

        it("Should receive some Hermes token and have decreased amount of PLTS", async () => {
            const alicePltsBalance = (await plutus.balanceOf(alice.address));
            const aliceHrmsBalance = (await hermes.balanceOf(alice.address));

            await plutus.connect(alice).approve(hermes.address, alicePltsBalance);
            await hermes.connect(alice).deposit(alicePltsBalance);

            const newAliceHrmsBalance = (await hermes.balanceOf(alice.address));
            const newAlicePltsBalance = (await plutus.balanceOf(alice.address));

            expect(newAliceHrmsBalance).to.be.gt(aliceHrmsBalance);
            expect(newAlicePltsBalance).to.be.lt(alicePltsBalance);
        });
    });
    describe("when cap is reached", () => {

        beforeEach("Mint the max amount", async () => {
            const maxSupply = await hermes.cap();
            await hermes.mint(alice.address, maxSupply);
        });

        it("Should have a total supply equal to max supply", async () => {
            const maxSupply = await hermes.cap();
            const totalSupply = await hermes.totalSupply();
            expect(totalSupply).to.be.equal(maxSupply);
        });

        it("Should revert on deposit due to max supply being reached.", async () => {
            const alicePltsBalance = (await plutus.balanceOf(alice.address)).toString();

            await plutus.connect(alice).approve(hermes.address, alicePltsBalance);
            // exect revert | cap reached
            await expect(hermes.connect(alice).deposit(alicePltsBalance)).to.be.revertedWith("ERC20Capped: cap exceeded")

        });
    });
});