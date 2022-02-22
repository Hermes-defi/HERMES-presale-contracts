const { ethers } = require('hardhat');
const { expect, assert } = require('chai');

describe('L3TokenRedeem Contract Test', function () {
    this.timeout(0); // this is important toprevent timeout when increasing blocks.
    let deployer, alice, bob, charlie, david, attacker;
    let users;

    const PLUTUS_SUPPLY = ethers.utils.parseEther('834686'); // 834k tokens

    const PHERMES_SUPPLY = ethers.utils.parseEther('107375'); // 107k tokens

    const HERMES_SUPPLY = ethers.utils.parseEther('250000'); // 250k tokens


    const PRESALE_START_BLOCK = 50;
    const PRESALE_END_BLOCK = PRESALE_START_BLOCK + 71999;
    const REDEEM_START_BLOCK = 70;
    before(async function () {

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice, bob, charlie, david];

        const L3PltsSwapFactory = await ethers.getContractFactory('L3PltsSwap', deployer);
        const L3TokenRedeemFactory = await ethers.getContractFactory('L3HermesTokenRedeem', deployer);
        const ERC20Factory = await ethers.getContractFactory('MockERC20', deployer);

        // deploy contracts
        this.plutus = await ERC20Factory.deploy("Plutus", "PLTS", PLUTUS_SUPPLY);

        this.pHermes = await ERC20Factory.deploy("pHermes", "pHRMS", PHERMES_SUPPLY);

        this.hermes = await ERC20Factory.deploy("Hermes", "HRMS", HERMES_SUPPLY);

        this.l3PltsSwap = await L3PltsSwapFactory.deploy(PRESALE_START_BLOCK, this.plutus.address, this.pHermes.address);

        this.l3TokenRedeem = await L3TokenRedeemFactory.deploy(REDEEM_START_BLOCK, this.l3PltsSwap.address, this.pHermes.address, this.hermes.address);

        // fund users account with 1000 hermes each

        for (let i = 0; i < users.length; i++) {
            const amount = ethers.utils.parseEther('1000');

            await this.pHermes.transfer(users[i].address, amount);

            await this.pHermes.connect(users[i]).approve(this.l3TokenRedeem.address, amount);

            expect(
                await this.pHermes.balanceOf(users[i].address)
            ).to.be.eq(amount);

        }

        // fund contract with hermes to use in swap.

        await this.hermes.transfer(this.l3TokenRedeem.address, HERMES_SUPPLY);
        expect(
            await this.hermes.balanceOf(this.l3TokenRedeem.address)
        ).to.be.eq(HERMES_SUPPLY);
    });

    it("Should revert because presale did not start.", async function () {
        const amount = ethers.utils.parseEther('1000');

        await expect(this.l3TokenRedeem.connect(alice).swapPreHermesForHermes(amount)).to.be.revertedWith("token redemption hasn't started yet, good things come to those that wait");
    });


    it("Should revert when trying to send unclaimed tokens to fee address", async function () {

        await expect(this.l3TokenRedeem.sendUnclaimedsToFeeAddress()).to.be.revertedWith("can only retrieve excess tokens after plts swap has ended");
    });


    it("Should revert when user try to swap if redeem has not started", async function () {
        const amount = ethers.utils.parseEther('1000');
        await expect(this.l3TokenRedeem.connect(alice).swapPreHermesForHermes(amount)).to.be.revertedWith("token redemption hasn't started yet, good things come to those that wait");
    });


    it("User should receive hermes token at 1:1 ratio from presale hermes token swap", async function () {
        const currentBlock = await ethers.provider.getBlockNumber();
        const increment = REDEEM_START_BLOCK - currentBlock;

        // increase block to start redeem
        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }

        const amount = ethers.utils.parseEther('1000');
        await this.l3TokenRedeem.connect(alice).swapPreHermesForHermes(amount);

        // expect pHrms balance to be zero
        expect(await this.pHermes.balanceOf(alice.address)).to.be.eq('0');
        // expect pHrms to get burned
        expect(await this.pHermes.balanceOf(await this.l3TokenRedeem.BURN_ADDRESS())).to.be.eq(amount);
        // expect user hermes balance to be equal to previous pHrms amount
        expect(await this.hermes.balanceOf(alice.address)).to.be.eq(amount);

    });

    it("Should be able to send unclaimed Hermes to fee address once presale ended.", async function () {
        const initialFeeAddrBalance = await this.hermes.balanceOf(await this.l3TokenRedeem.FEE_ADDRESS());

        const currentBlock = await ethers.provider.getBlockNumber();
        const increment = PRESALE_END_BLOCK - currentBlock;
        console.log("Mining blocks. This may take a moment...");
        // increase block to start redeem
        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }
        await this.l3TokenRedeem.sendUnclaimedsToFeeAddress();
        const finalFeeAddrBalance = await this.hermes.balanceOf(await this.l3TokenRedeem.FEE_ADDRESS());

        expect(finalFeeAddrBalance).to.be.gt(initialFeeAddrBalance);
    });
});