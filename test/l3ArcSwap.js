const { ethers } = require('hardhat');
const { expect, assert } = require('chai');

describe('L3ArcSwap Contract Test', function () {
    this.timeout(0); // this is important toprevent timeout when increasing blocks.
    let deployer, alice, bob, charlie, david, attacker;
    let users;

    const ARCADIA_SUPPLY = ethers.utils.parseEther('834686'); // 1 million tokens
    const PDIAMOND_SUPPLY = ethers.utils.parseEther('12885'); // 1 million tokens
    const PDARKSIDE_SUPPLY = ethers.utils.parseEther('107375'); // 1 million tokens

    const PRESALE_START_BLOCK = 7000;
    const PRESALE_END_BLOCK = PRESALE_START_BLOCK + 71999;
    before(async function () {

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice, bob, charlie, david];

        const L3ArcSwapFactory = await ethers.getContractFactory('L3ArcSwap', deployer);
        const ERC20Factory = await ethers.getContractFactory('MockERC20', deployer);

        // deploy contracts
        this.arcadia = await ERC20Factory.deploy("Arcadia", "ARC", ARCADIA_SUPPLY);
        this.pDiamond = await ERC20Factory.deploy("pDiamond", "PDIA", PDIAMOND_SUPPLY);
        this.pDarkside = await ERC20Factory.deploy("pDarkside", "PDARK", PDARKSIDE_SUPPLY);
        this.l3ArcSwap = await L3ArcSwapFactory.deploy(PRESALE_START_BLOCK, this.arcadia.address, this.pDiamond.address, this.pDarkside.address);


        // fund users account with 1000 arcadia each

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

    it("Max pToken Should increase after changing the sale price (pl3/l2) to the Min", async function () {
        const pDiaPrice = ethers.utils.parseEther('10000000000000000');
        const pDarkPrice = ethers.utils.parseEther('90000000000000000');

        // get curent max available
        const oldMaxDiamond = await this.l3ArcSwap.preCZDiamondMaximumAvailable();
        const oldMaxDark = await this.l3ArcSwap.preDarksideMaximumAvailable();

        await this.l3ArcSwap.setSaleINVPriceE35(pDiaPrice, pDarkPrice);

        // compare old price with new price
        const newDiamondSalePrice = await this.l3ArcSwap.preCZDiamondSaleINVPriceE35();
        const newDarkSalePrice = await this.l3ArcSwap.preDarksideSaleINVPriceE35();

        expect(newDiamondSalePrice).to.be.eq(pDiaPrice);
        expect(newDarkSalePrice).to.be.eq(pDarkPrice);

        // compare old max with new max
        const newMaxDiamond = await this.l3ArcSwap.preCZDiamondMaximumAvailable();
        const newMaxDark = await this.l3ArcSwap.preDarksideMaximumAvailable();

        expect(newMaxDiamond).to.be.gt(oldMaxDiamond);
        expect(newMaxDark).to.be.gt(oldMaxDark);

    });
    it("Max pToken Should decrease after changing the sale price (pl3/l2) to the max", async function () {
        const pDiaPrice = ethers.utils.parseEther('100000000000000');
        const pDarkPrice = ethers.utils.parseEther('900000000000000');

        // get curent max available
        const oldMaxDiamond = await this.l3ArcSwap.preCZDiamondMaximumAvailable();
        const oldMaxDark = await this.l3ArcSwap.preDarksideMaximumAvailable();

        await this.l3ArcSwap.setSaleINVPriceE35(pDiaPrice, pDarkPrice);

        // compare old price with new price
        const newDiamondSalePrice = await this.l3ArcSwap.preCZDiamondSaleINVPriceE35();
        const newDarkSalePrice = await this.l3ArcSwap.preDarksideSaleINVPriceE35();

        expect(newDiamondSalePrice).to.be.eq(pDiaPrice);
        expect(newDarkSalePrice).to.be.eq(pDarkPrice);

        // compare old max with new max
        const newMaxDiamond = await this.l3ArcSwap.preCZDiamondMaximumAvailable();
        const newMaxDark = await this.l3ArcSwap.preDarksideMaximumAvailable();

        expect(newMaxDiamond).to.be.lt(oldMaxDiamond);
        expect(newMaxDark).to.be.lt(oldMaxDark);

    });

    it("Should revert when trying to change sale price within hours of presale", async function () {
        // increase block to have at least 1 hour time efore presale
        const currentBlock = await ethers.provider.getBlockNumber();

        const increment = PRESALE_START_BLOCK - currentBlock - 10;

        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }
    });

    it("All user should receive the same amount of pTokens after swapping", async function () {
        // increment block
        const currentBlock = await ethers.provider.getBlockNumber();
        assert.equal(await this.pDarkside.balanceOf(alice.address), '0');
        const increment = PRESALE_START_BLOCK - currentBlock;

        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }

        // swap token using all but 1 user.
        for (let i = 0; i < users.length - 1; i++) {
            const amount = ethers.utils.parseEther('1000');
            await this.l3ArcSwap.connect(users[i]).swapArcForPresaleTokensL3(amount);
        }

        // check proper balances
        expect(
            await this.pDiamond.balanceOf(alice.address)
        ).to.be.eq(await this.pDiamond.balanceOf(bob.address));

        expect(
            await this.pDarkside.balanceOf(alice.address)
        ).to.be.eq(await this.pDarkside.balanceOf(bob.address));

        expect(
            await this.pDarkside.balanceOf(alice.address)
        ).to.be.gt('0');

        expect(
            await this.arcadia.balanceOf(alice.address)
        ).to.be.eq('0');
    });

    it("Should revert when sending deprecated tokens if presale has not ended", async function () {
        // try to send deprecated to fee addr
        // expect it to revert with msg "can only retrieve excess tokens after arcadium swap has ended"
        await expect(this.l3ArcSwap.sendDepreciatedArcToFeeAddress()).to.be.revertedWith("can only retrieve excess tokens after arcadium swap has ended");
    });

    it("Should revert when user deposit after presale ended presale ended.", async function () {

        const currentBlock = await ethers.provider.getBlockNumber();
        const increment = PRESALE_END_BLOCK - currentBlock;
        console.log("increasing block. This may take a moment...");
        // advance block number
        // NB: this will take unsually long. Use logger to see that its working.
        //TODO: switch to using hardhat_mine when released [https://github.com/NomicFoundation/hardhat/issues/1112]
        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
            // console.log(await ethers.provider.getBlockNumber());
        }

        // swapping should revert
        const amount = ethers.utils.parseEther('1000');
        await expect(this.l3ArcSwap.connect(david).swapArcForPresaleTokensL3(amount)).to.be.revertedWith("presale has ended, come back next time!");

    });

    it("Fee address should have total arcadia balance after after retreiving it.", async function () {
        // get contract arcadia balance
        const contractBalance = await this.arcadia.balanceOf(this.l3ArcSwap.address);
        const feeAddressBalance = await this.arcadia.balanceOf(await this.l3ArcSwap.feeAddress());

        // retreive arcadia from contract
        await this.l3ArcSwap.sendDepreciatedArcToFeeAddress();

        // expect contract to have zero balance.
        expect(await this.arcadia.balanceOf(this.l3ArcSwap.address)).to.be.eq('0');

        // expect fee address to have the previous contract balance.
        expect(await this.arcadia.balanceOf(await this.l3ArcSwap.feeAddress())).to.be.eq(contractBalance);
    });
});