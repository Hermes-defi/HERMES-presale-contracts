const { ethers } = require('hardhat');
const { expect, assert } = require('chai');

describe('L3PlutusSwapBank Contract Test', function () {
    this.timeout(0); // this is important to prevent timeout when increasing blocks.
    let deployer, alice, bob, charlie, david, attacker;
    let users;
    let whiteListedAmount;

    const PLUTUS_SUPPLY = ethers.utils.parseEther('714285.7143'); // ~700k tokens
    const PHERMES_SUPPLY = ethers.utils.parseEther('1811855'); // ~1M tokens


    const PRESALE_START_BLOCK = 7000;
    const PRESALE_END_BLOCK = PRESALE_START_BLOCK + 117360;
    before(async function () {

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice, bob, charlie, david];

        const L3PlutusSwapFactory = await ethers.getContractFactory('L3PltsSwapBank', deployer);
        const ERC20Factory = await ethers.getContractFactory('MockERC20', deployer);

        // deploy contracts
        this.plutus = await ERC20Factory.deploy("Plutus", "PLTS", PLUTUS_SUPPLY);
        this.pHermes = await ERC20Factory.deploy("pHermes", "pHRMS", PHERMES_SUPPLY);
        this.l3PlutusSwapBank = await L3PlutusSwapFactory.deploy(PRESALE_START_BLOCK, this.plutus.address, this.pHermes.address);


        // fund users account with 1000 plutus each

        for (let i = 0; i < users.length; i++) {
            const walletBalance = ethers.utils.parseEther('1000');
            whiteListedAmount = ethers.utils.parseEther('500');

            await this.plutus.transfer(users[i].address, walletBalance);
            await this.plutus.connect(users[i]).approve(this.l3PlutusSwapBank.address, walletBalance);

            // whitelist bank users
            await this.l3PlutusSwapBank.whitelistUser(users[i].address, whiteListedAmount);

            expect(
                await this.plutus.balanceOf(users[i].address)
            ).to.be.eq(walletBalance);
        }
        // fund attacker account
        const attackerBalance = ethers.utils.parseEther('1000');
        await this.plutus.transfer(attacker.address, attackerBalance);
        await this.plutus.connect(attacker).approve(this.l3PlutusSwapBank.address, attackerBalance);

        // fund swap contract
        await this.pHermes.transfer(this.l3PlutusSwapBank.address, PHERMES_SUPPLY);


        expect(
            await this.pHermes.balanceOf(this.l3PlutusSwapBank.address)
        ).to.be.eq(PHERMES_SUPPLY);
    });

    it("Should revert because presale did not start.", async function () {
        const amount = ethers.utils.parseEther('1000');
        await expect(this.l3PlutusSwapBank.connect(alice).swapPltsForPresaleTokensL3(amount)).to.be.revertedWith("presale hasn't started yet, good things come to those that wait");
    });

    it("Max pHermes available should increase after changing the sale price (pl3/l2) to the min price", async function () {

        const pHermesPrice = ethers.utils.parseEther('80000000000000000');

        // get curent max available

        const oldMaxHermes = await this.l3PlutusSwapBank.preHermesMaximumAvailable();

        await this.l3PlutusSwapBank.setSaleINVPriceE35(pHermesPrice);

        // compare old price with new price

        const newHermesSalePrice = await this.l3PlutusSwapBank.preHermesSaleINVPriceE35();


        expect(newHermesSalePrice).to.be.eq(pHermesPrice);

        // compare old max with new max

        const newMaxHermes = await this.l3PlutusSwapBank.preHermesMaximumAvailable();


        expect(newMaxHermes).to.be.gt(oldMaxHermes);

    });

    it("Max pHermes available should decrease after changing the sale price (pl3/l2) to max price", async function () {

        const pHermesPrice = ethers.utils.parseEther('66000000000000000');

        // get curent max available

        const oldMaxHermes = await this.l3PlutusSwapBank.preHermesMaximumAvailable();

        await this.l3PlutusSwapBank.setSaleINVPriceE35(pHermesPrice);

        // compare old price with new price

        const newHermesSalePrice = await this.l3PlutusSwapBank.preHermesSaleINVPriceE35();


        expect(newHermesSalePrice).to.be.eq(pHermesPrice);

        // compare old max with new max

        const newMaxHermes = await this.l3PlutusSwapBank.preHermesMaximumAvailable();


        expect(newMaxHermes).to.be.lt(oldMaxHermes);

    });

    it("Max pHermes available should equal 966,929.57 after changing the sale price to 0.66101 (pl3/l2) ", async function () {
        const pHermesPrice = ethers.utils.parseEther('66101694920000000');

        const max_pHermes = ethers.utils.parseEther('966929.57');
        const delta = ethers.utils.parseEther('0.1');

        // get curent max available

        const oldMaxHermes = await this.l3PlutusSwapBank.preHermesMaximumAvailable();

        await this.l3PlutusSwapBank.setSaleINVPriceE35(pHermesPrice);

        // compare old price with new price

        const newHermesSalePrice = await this.l3PlutusSwapBank.preHermesSaleINVPriceE35();


        expect(newHermesSalePrice).to.be.eq(pHermesPrice);

        // compare old max with new max

        const newMaxHermes = await this.l3PlutusSwapBank.preHermesMaximumAvailable();


        // expect(newMaxHermes).to.be.eq(max_pHermes);
        expect(newMaxHermes).to.be.closeTo(max_pHermes, delta);

    });

    it("Should revert when trying to change sale price within hours of presale", async function () {
        // increase block to have at least 1 hour time efore presale

        const pHermesPrice = ethers.utils.parseEther('900000000000000');

        const currentBlock = await ethers.provider.getBlockNumber();

        const increment = PRESALE_START_BLOCK - currentBlock - 10;

        console.log("Mining blocks. This may take a moment...");
        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }
        await expect(this.l3PlutusSwapBank.setSaleINVPriceE35(pHermesPrice)).to.be.revertedWith("cannot change price 4 hours before start block");
    });

    it("All users should receive ~0.66 pHermes after swapping 1 Plutus", async function () {
        const delta = ethers.utils.parseEther('0.0011');
        const pHermesReceived = ethers.utils.parseEther('0.66');

        // increment block
        const currentBlock = await ethers.provider.getBlockNumber();
        assert.equal(await this.pHermes.balanceOf(alice.address), '0');
        const increment = PRESALE_START_BLOCK - currentBlock;

        console.log("Mining blocks. This may take a moment...");
        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }

        // swap token using all but 1 user.
        for (let i = 0; i < users.length - 1; i++) {
            const amount = ethers.utils.parseEther('1');
            await this.l3PlutusSwapBank.connect(users[i]).swapPltsForPresaleTokensL3(amount);
        }

        // check proper balances

        expect(
            await this.pHermes.balanceOf(alice.address)
        ).to.be.eq(await this.pHermes.balanceOf(bob.address));

        expect(await this.pHermes.balanceOf(alice.address)).to.be.closeTo(pHermesReceived, delta);

        expect(
            await this.plutus.balanceOf(alice.address)
        ).to.be.eq(ethers.utils.parseEther('999'));
    });

    it("Users should have their allowance decreased by 1 PLTS", async function () {
        const userAllowance = await this.l3PlutusSwapBank.swapAllowance(alice.address);
        expect(userAllowance).to.be.eq(ethers.utils.parseEther('499'));
    });

    it("Should revert when users try to swap more than their allowance", async function () {
        const bobRemainingBalance = await this.plutus.balanceOf(bob.address);
        assert.isAbove(bobRemainingBalance, whiteListedAmount);
        await expect(this.l3PlutusSwapBank.connect(bob).swapPltsForPresaleTokensL3(bobRemainingBalance)).to.be.revertedWith("Not allowed to swap this much PLTS");

    });

    it("Should revert when non whitelisted users tries to swap", async function () {
        const amount = ethers.utils.parseEther('999');
        await expect(this.l3PlutusSwapBank.connect(attacker).swapPltsForPresaleTokensL3(amount)).to.be.revertedWith("User is not Allowed.");
    });

    it("Should revert when sending deprecated tokens if presale has not ended", async function () {
        // try to send deprecated to fee addr
        // expect it to revert with msg "can only retrieve excess tokens after plutus swap has ended"
        await expect(this.l3PlutusSwapBank.sendDepreciatedPltsToFeeAddress()).to.be.revertedWith("can only retrieve excess tokens after plutus swap has ended");
    });

    it("Should revert when user deposit after presale ended.", async function () {

        const currentBlock = await ethers.provider.getBlockNumber();
        const increment = PRESALE_END_BLOCK - currentBlock;
        console.log("Mining blocks. This may take a moment...");
        // advance block number
        // NB: this will take unsually long. Use logger to see that its working.
        //TODO: switch to using hardhat_mine when released [https://github.com/NomicFoundation/hardhat/issues/1112]
        for (let i = 0; i < increment; i++) {
            await ethers.provider.send("evm_mine");
        }

        // swapping should revert
        const amount = ethers.utils.parseEther('1000');
        await expect(this.l3PlutusSwapBank.connect(david).swapPltsForPresaleTokensL3(amount)).to.be.revertedWith("presale has ended, come back next time!");

    });

    it("Fee address should have total plutus balance after after retreiving it.", async function () {
        // get contract plutus balance
        const contractBalance = await this.plutus.balanceOf(this.l3PlutusSwapBank.address);

        // retreive plutus from contract
        await this.l3PlutusSwapBank.sendDepreciatedPltsToFeeAddress();

        // expect contract to have zero balance.
        expect(await this.plutus.balanceOf(this.l3PlutusSwapBank.address)).to.be.eq('0');

        // expect fee address to have the previous contract balance.
        expect(await this.plutus.balanceOf(await this.l3PlutusSwapBank.FEE_ADDRESS())).to.be.eq(contractBalance);
    });
});