const { ethers } = require('hardhat');
const { expect, assert } = require('chai');



function toWei(v) {
    return ethers.utils.parseUnits(v, 18).toString();
}



describe("Hermes", function () {
    let deployer, alice, bob, attacker;
    let users;
    beforeEach("Deploy contracts", async function () {

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();

        const HermesFactory = await ethers.getContractFactory("Hermes", deployer);

        // hermes = await HermesFactory.deploy("HERMES", "HRMS");
        hermes = await HermesFactory.deploy();
        await hermes.deployed();



        assert.equal((await hermes.cap()).toString(), toWei('30000000'));
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

        it("Should revert on mint due to max supply being reached.", async () => {

            await expect(hermes.mint(alice.address, '500')).to.be.revertedWith("ERC20Capped: cap exceeded")

        });
    });
});