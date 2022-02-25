const { ethers } = require('hardhat');
const { expect, assert } = require('chai');

describe('L3TokenRedeem Contract Test', function () {
    this.timeout(0); // this is important toprevent timeout when increasing blocks.
    let deployer, alice, bob, charlie, david, attacker;
    let users;

    const ARCADIA_SUPPLY = ethers.utils.parseEther('834686'); // 834k tokens
    const PDIAMOND_SUPPLY = ethers.utils.parseEther('12885'); // 12k tokens
    const PDARKSIDE_SUPPLY = ethers.utils.parseEther('107375'); // 107k tokens
    const DIAMOND_SUPPLY = ethers.utils.parseEther('30000'); // 30k tokens
    const DARKSIDE_SUPPLY = ethers.utils.parseEther('250000'); // 250k tokens


    const PRESALE_START_BLOCK = 50;
    const PRESALE_END_BLOCK = PRESALE_START_BLOCK + 71999;
    const REDEEM_START_BLOCK = 70;
    before(async function () {

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice, bob, charlie, david];

        const L3ArcSwapFactory = await ethers.getContractFactory('L3ArcSwap', deployer);
        const L3TokenRedeemFactory = await ethers.getContractFactory('L3TokenRedeem', deployer);
        const ERC20Factory = await ethers.getContractFactory('MockERC20', deployer);

        // deploy contracts
        this.arcadia = await ERC20Factory.deploy("Arcadia", "ARC", ARCADIA_SUPPLY);

        this.pDiamond = await ERC20Factory.deploy("pDiamond", "PDIA", PDIAMOND_SUPPLY);
        this.pDarkside = await ERC20Factory.deploy("pDarkside", "PDARK", PDARKSIDE_SUPPLY);

        this.diamond = await ERC20Factory.deploy("Diamond", "DIA", DIAMOND_SUPPLY);
        this.darkside = await ERC20Factory.deploy("Darkside", "DARK", DARKSIDE_SUPPLY);

        this.l3ArcSwap = await L3ArcSwapFactory.deploy(PRESALE_START_BLOCK, this.arcadia.address, this.pDiamond.address, this.pDarkside.address);
        this.l3MFSwap = await L3ArcSwapFactory.deploy(PRESALE_START_BLOCK, this.arcadia.address, this.pDiamond.address, this.pDarkside.address);

        this.l3TokenRedeem = await L3TokenRedeemFactory.deploy(REDEEM_START_BLOCK, this.l3ArcSwap.address, this.l3MFSwap.address, this.pDiamond.address, this.pDarkside.address, this.diamond.address, this.darkside.address);


        // fund users account with 1000 diamond and darkside each

        for (let i = 0; i < users.length; i++) {
            const amount = ethers.utils.parseEther('1000');
            await this.pDiamond.transfer(users[i].address, amount);
            await this.pDarkside.transfer(users[i].address, amount);

            await this.pDiamond.connect(users[i]).approve(this.l3TokenRedeem.address, amount);
            await this.pDarkside.connect(users[i]).approve(this.l3TokenRedeem.address, amount);

            expect(
                await this.pDarkside.balanceOf(users[i].address)
            ).to.be.eq(amount);
            expect(
                await this.pDiamond.balanceOf(users[i].address)
            ).to.be.eq(amount);
        }

        // fund contract with diamond and darkside to use in swap.
        await this.diamond.transfer(this.l3TokenRedeem.address, DIAMOND_SUPPLY);
        await this.darkside.transfer(this.l3TokenRedeem.address, DARKSIDE_SUPPLY);

        expect(
            await this.diamond.balanceOf(this.l3TokenRedeem.address)
        ).to.be.eq(DIAMOND_SUPPLY);
        expect(
            await this.darkside.balanceOf(this.l3TokenRedeem.address)
        ).to.be.eq(DARKSIDE_SUPPLY);
    });


    // it("", async function () { });
    // it("", async function () { });
    // it("", async function () { });

    it("Should revert because presale did not start.", async function () {
        const amount = ethers.utils.parseEther('1000');
        await expect(this.l3TokenRedeem.connect(alice).swapPreCZDiamondForCZDiamond(amount)).to.be.revertedWith("token redemption hasn't started yet, good things come to those that wait");
        await expect(this.l3TokenRedeem.connect(alice).swapPreDarksideForDarkside(amount)).to.be.revertedWith("token redemption hasn't started yet, good things come to those that wait");

    });


    it("Should revert when trying to send unclaimed tokens to fee address", async function () {

        await expect(this.l3TokenRedeem.sendUnclaimedsToFeeAddress()).to.be.revertedWith("can only retrieve excess tokens after arc swap has ended");
    });


    it("Should revert when user try to swap if redeem has not started", async function () {
        const amount = ethers.utils.parseEther('1000');
        await expect(this.l3TokenRedeem.connect(alice).swapPreDarksideForDarkside(amount)).to.be.revertedWith("token redemption hasn't started yet, good things come to those that wait");
    });


    it("User should receive darkside token at 1:1 ratio from presale darkside token swap", async function () {
        const currentBlock = await ethers.provider.getBlockNumber();
        const increment = REDEEM_START_BLOCK - currentBlock;

        // increase block to start redeem
        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }


        const amount = ethers.utils.parseEther('1000');
        await this.l3TokenRedeem.connect(alice).swapPreDarksideForDarkside(amount);


        // expect pDark balance to be zero
        expect(await this.pDarkside.balanceOf(alice.address)).to.be.eq('0');
        // expect pDark to get burned
        expect(await this.pDarkside.balanceOf(await this.l3TokenRedeem.BURN_ADDRESS())).to.be.eq(amount);
        // expect user darkside balance to be equal to previous Pdark amount
        expect(await this.darkside.balanceOf(alice.address)).to.be.eq(amount);

    });

    it("Should be able to send unclaimed Darkside to fee address once presale ended.", async function () {
        const initialFeeAddrBalance = await this.darkside.balanceOf(await this.l3TokenRedeem.feeAddress());

        const currentBlock = await ethers.provider.getBlockNumber();
        const increment = PRESALE_END_BLOCK - currentBlock;
        console.log("increasing block. This may take a moment...");
        // increase block to start redeem
        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }
        await this.l3TokenRedeem.sendUnclaimedsToFeeAddress();
        const finalFeeAddrBalance = await this.darkside.balanceOf(await this.l3TokenRedeem.feeAddress());

        expect(finalFeeAddrBalance).to.be.gt(initialFeeAddrBalance);
    });
});