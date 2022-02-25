const { ethers } = require('hardhat');
const { expect, assert } = require('chai');

describe('L3TokenRedeem Contract Test', function () {
    this.timeout(0); // this is important toprevent timeout when increasing blocks.
    let deployer, alice, bob, charlie, david, attacker;
    let users;

    const PLUTUS_SUPPLY = ethers.utils.parseEther('2350000'); // 2.35M tokens

    const PHERMES_SUPPLY = ethers.utils.parseEther('1811854.103'); // 1.811M tokens

    const HERMES_SUPPLY = ethers.utils.parseEther('1811855'); // 1.811M tokens


    const PRESALE_START_BLOCK = 50;
    const PRESALE_END_BLOCK = PRESALE_START_BLOCK + 117360;
    const REDEEM_START_BLOCK = 70;
    before(async function () {

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice, bob, charlie, david];

        const L3PltsSwapBankFactory = await ethers.getContractFactory('L3PltsSwapBank', deployer);
        const L3PltsSwapGenFactory = await ethers.getContractFactory('L3PltsSwapGen', deployer);
        const L3TokenRedeemFactory = await ethers.getContractFactory('L3HermesTokenRedeem', deployer);
        const ERC20Factory = await ethers.getContractFactory('MockERC20', deployer);

        // deploy contracts
        this.plutus = await ERC20Factory.deploy("Plutus", "PLTS", PLUTUS_SUPPLY);
        this.pHermes = await ERC20Factory.deploy("pHermes", "pHRMS", PHERMES_SUPPLY);
        this.hermes = await ERC20Factory.deploy("Hermes", "HRMS", HERMES_SUPPLY);

        this.l3PltsSwapBank = await L3PltsSwapBankFactory.deploy(PRESALE_START_BLOCK, this.plutus.address, this.pHermes.address);
        this.l3PltsSwapGen = await L3PltsSwapGenFactory.deploy(PRESALE_START_BLOCK, this.plutus.address, this.pHermes.address);

        this.l3TokenRedeem = await L3TokenRedeemFactory.deploy(REDEEM_START_BLOCK, this.l3PltsSwapBank.address, this.l3PltsSwapGen.address, this.pHermes.address, this.hermes.address);

        // fund each presale contract with pHermes needed.
        const bankAmount = ethers.utils.parseEther('1061854.103');
        const genAmount = ethers.utils.parseEther('750000');
        await this.pHermes.transfer(this.l3PltsSwapBank.address, bankAmount);
        await this.pHermes.transfer(this.l3PltsSwapGen.address, genAmount);

        // fund users account with 1000 plutus each and approve spending.
        for (let i = 0; i < users.length; i++) {
            const amount = ethers.utils.parseEther('1000');

            await this.plutus.transfer(users[i].address, amount);

            await this.plutus.connect(users[i]).approve(this.l3PltsSwapBank.address, amount);
            await this.plutus.connect(users[i]).approve(this.l3PltsSwapGen.address, amount);

            expect(
                await this.plutus.balanceOf(users[i].address)
            ).to.be.eq(amount);

        }

        // fund redeem contract with hermes.

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

        await expect(this.l3TokenRedeem.sendUnclaimedsToFeeAddress()).to.be.revertedWith("can only retrieve excess tokens after presale has ended.");
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
        let pHermesBalance;
        for (let i = 0; i < users.length; i++) {
            const amount = ethers.utils.parseEther('1');
            await this.l3PltsSwapGen.connect(users[i]).swapPltsForPresaleTokensL3(amount);
            pHermesBalance = await this.pHermes.balanceOf(users[i].address);
            await this.pHermes.connect(users[i]).approve(this.l3TokenRedeem.address, pHermesBalance)
            await this.l3TokenRedeem.connect(users[i]).swapPreHermesForHermes(pHermesBalance);
        }

        const burnAmount = ethers.utils.parseEther('1.8340611352');
        // await this.l3TokenRedeem.connect(alice).swapPreHermesForHermes(amount);

        // expect pHrms balance to be zero
        expect(await this.pHermes.balanceOf(alice.address)).to.be.eq('0');

        // expect pHrms to get burned
        expect(await this.pHermes.balanceOf(await this.l3TokenRedeem.BURN_ADDRESS())).to.be.eq(burnAmount);

        // expect user hermes balance to be equal to previous pHrms amount
        expect(await this.hermes.balanceOf(alice.address)).to.be.eq(pHermesBalance);

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