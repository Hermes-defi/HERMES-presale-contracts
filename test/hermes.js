const { ethers, network } = require('hardhat');
const { expect, assert } = require('chai');

function toWei(v) {
    return ethers.utils.parseUnits(v, 18).toString();
}

describe("Hermes", function () {
    let deployer, alice, bob, charlie, david, attacker;
    let users;
    beforeEach("Deploy contracts", async function () {

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        const HermesFactory = await ethers.getContractFactory("Hermes", deployer);


        hermes = await HermesFactory.deploy();
        await hermes.deployed();

        assert.equal((await hermes.cap()).toString(), toWei('30000000'));
    });

    describe("when Minter roles are required", () => {

        beforeEach("give minter role to charlie", async () => {
            await hermes.grantMinterRole(charlie.address);
        });

        it("should mint when user with minter role tries to mint", async () => {
            const mintAmount = ethers.utils.parseEther('10');
            await hermes.connect(charlie).mint(charlie.address, mintAmount);
            const charlieBalance = await hermes.balanceOf(charlie.address);
            expect(charlieBalance).to.be.eq(mintAmount)
        });
        it("should revert when non minter role tries to mint", async () => {
            const mintAmount = ethers.utils.parseEther('10');
            await expect(hermes.connect(alice).mint(alice.address, mintAmount)).to.be.reverted;
        });
    });
    describe("when Burner roles are required", () => {

        beforeEach("give Burner role to charlie", async () => {
            transferAmount = await ethers.utils.parseEther('10');
            await hermes.mint(alice.address, transferAmount);
            await hermes.grantBurnerRole(charlie.address);
        });

        it("should burn when user with burner role tries to burn", async () => {
            const burnAmount = ethers.utils.parseEther('10');
            await hermes.connect(charlie).burn(alice.address, burnAmount);
            const aliceBalance = await hermes.balanceOf(alice.address);
            expect(aliceBalance).to.be.eq('0')
        });
        it("should revert when non burner role tries to burn", async () => {
            const burnAmount = ethers.utils.parseEther('10');
            await expect(hermes.connect(alice).burn(alice.address, burnAmount)).to.be.reverted;
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

        it("Should revert on mint due to max supply being reached.", async () => {

            await expect(hermes.mint(alice.address, '500')).to.be.revertedWith("ERC20Capped: cap exceeded")
        });
    });
    describe("when ownership is transferred", () => {

        beforeEach("transfer ownership", async () => {
            await hermes.transferOwnership(alice.address);
        });

        it("alice should be new owner", async () => {

            expect((await hermes.owner())).to.be.equal(alice.address);
        });

        it("deployer should not be able to revoke roles", async () => {

            await expect(hermes.connect(deployer).revokeMinterRole(charlie.address)).to.be.reverted;
        });
        it("alice should be able to revoke roles", async () => {

            await expect(hermes.connect(alice).revokeMinterRole(charlie.address)).to.not.be.reverted;
        });
    });

    after(async function () {
        await network.provider.request({
            method: "hardhat_reset",
            params: [],
        })
    })

});