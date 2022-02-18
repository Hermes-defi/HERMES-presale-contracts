const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('L3ArcSwap Contract Test', function () {

    let deployer, alice, bob, charlie, david, attacker;
    let users;

    const ARCADIA_SUPPLY = ethers.utils.parseEther('834686'); // 1 million tokens
    const PDIAMOND_SUPPLY = ethers.utils.parseEther('12885'); // 1 million tokens
    const PDARKSIDE_SUPPLY = ethers.utils.parseEther('107375'); // 1 million tokens

    const PRESALE_START_BLOCK = 20;
    const PRESALE_END_BLOCK = PRESALE_START_BLOCK + 71999;
    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice, bob, charlie, david];

        const L3ArcSwapFactory = await ethers.getContractFactory('L3ArcSwap', deployer);
        const ERC20Factory = await ethers.getContractFactory('MockERC20', deployer);

        // deploy contracts
        this.arcadia = await ERC20Factory.deploy("Arcadia", "ARC", ARCADIA_SUPPLY);
        this.pDiamond = await ERC20Factory.deploy("pDiamond", "PDIA", PDIAMOND_SUPPLY);
        this.pDarkside = await ERC20Factory.deploy("pDarkside", "PDARK", PDARKSIDE_SUPPLY);
        this.l3ArcSwap = await L3ArcSwapFactory.deploy(PRESALE_START_BLOCK, this.arcadia.address, this.pDiamond.address, this.pDarkside.address);


        // fund users account

        for (let i = 0; i < users.length; i++) {
            const amount = ethers.utils.parseEther('1000');
            await this.arcadia.transfer(users[i].address, amount);
            await this.arcadia.connect(users[i]).approve(this.l3ArcSwap.address, amount);

            expect(
                await this.arcadia.balanceOf(users[i].address)
            ).to.be.eq(amount);
        }
        await this.pDiamond.transfer(this.l3ArcSwap.address, PDIAMOND_SUPPLY);
        await this.pDarkside.transfer(this.l3ArcSwap.address, PDARKSIDE_SUPPLY);

        expect(
            await this.pDiamond.balanceOf(this.l3ArcSwap.address)
        ).to.be.eq(PDIAMOND_SUPPLY);
        expect(
            await this.pDarkside.balanceOf(this.l3ArcSwap.address)
        ).to.be.eq(PDARKSIDE_SUPPLY);
    });

    // it("", async function () { });
    it("Should revert because presale did not start.", async function () {
        const amount = ethers.utils.parseEther('1000');
        await expect(this.l3ArcSwap.connect(alice).swapArcForPresaleTokensL3(amount)).to.be.revertedWith("presale hasn't started yet, good things come to those that wait");
    });


    it("All user should receive the same amount of pTokens", async function () {

        // advance to block
        const currentBlock = await ethers.provider.getBlockNumber();

        const increment = PRESALE_START_BLOCK - currentBlock;

        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }

        for (let i = 0; i < users.length; i++) {
            const amount = ethers.utils.parseEther('1000');
            await this.l3ArcSwap.connect(users[i]).swapArcForPresaleTokensL3(amount);

        }

        expect(
            await this.pDiamond.balanceOf(alice.address)
        ).to.be.eq(await this.pDiamond.balanceOf(bob.address));
        expect(
            await this.pDarkside.balanceOf(alice.address)
        ).to.be.eq(await this.pDarkside.balanceOf(bob.address));
        expect(
            await this.arcadia.balanceOf(alice.address)
        ).to.be.eq('0');
    });

    xit("Should revert because presale ended.", async function () {
        const currentBlock = await ethers.provider.getBlockNumber();
        console.log("current block", currentBlock, typeof currentBlock);

        const increment = PRESALE_END_BLOCK - currentBlock;
        console.log(increment);


        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }
        console.log(await ethers.provider.getBlockNumber());
    });
});