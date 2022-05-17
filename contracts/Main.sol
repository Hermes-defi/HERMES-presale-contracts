pragma solidity 0.8.0;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// import "hardhat/console.sol";
//import "./PreHermes.sol";
contract Main {
    uint public constant rateWhitelisted = 0.661016949 gwei;
    uint public constant ratePublic = 0.560399830 gwei;

    event convertWhitelistedStatus(address user, uint amount, uint payment);
    event convertPublicStatus(address user, uint amount, uint payment);

    IERC20 public plutus;
    IERC20 public preHermes;
    IERC20 public hermes;
    mapping(address => uint) whitelist;
    address public admin;
    address public treasure;

    uint public whitelistStartBlock;
    uint public whitelistEndBlock;

    uint public publicStartBlock;
    uint public publicEndBlock;

    uint public claimStartBlock;
    uint public claimEndBlock;

    constructor(address _plutus, address _preHermes, address _hermes){
        plutus = IERC20(_plutus);
        preHermes = IERC20(_preHermes);
        hermes = IERC20(_hermes);
        admin = msg.sender;
        treasure = msg.sender;
    }
    function convertWhitelisted(uint amount) public {
        _interval(whitelistStartBlock, whitelistEndBlock);
        require(whitelist[msg.sender] >= amount, "invalid amount");
        whitelist[msg.sender] -= amount;
        uint payment = _compute(amount, rateWhitelisted);
        _transferToTreasure(amount);
        preHermes.transfer(msg.sender, payment);
        emit convertWhitelistedStatus(msg.sender, amount, payment);
    }

    function convertPublic(uint amount) public {
        _interval(publicStartBlock, publicEndBlock);
        uint payment = _compute(amount, ratePublic);
        _transferToTreasure(amount);
        preHermes.transfer(msg.sender, payment);
        emit convertPublicStatus(msg.sender, amount, payment);
    }

    function claim(uint amount) public {
        _interval(claimStartBlock, claimEndBlock);
        preHermes.transferFrom(msg.sender, treasure, amount);
        hermes.transfer(msg.sender, amount);
    }

    function checkWhitelistBalance(address user) public view returns (uint whitelistBalance){
        whitelistBalance = whitelist[user];
    }

    function _transferToTreasure(uint amount) internal {
        plutus.transferFrom(msg.sender, treasure, amount);
    }

    function _compute(uint amount, uint rate) internal returns (uint){
        return ((amount / 1e9) * rate) / 1e9;
    }

    function _interval(uint start, uint end) internal view {
        require(start == 0 || block.number >= start, "no start");
        require(end == 0 || block.number <= end, "already ended");
    }

    function adminChangeAdmin(address newAdmin) external {
        require(admin == msg.sender, "no admin");
        admin = newAdmin;
    }

    function adminChangeTreasure(address newTreasure) external {
        require(admin == msg.sender, "no admin");
        treasure = newTreasure;
    }

    function adminSetWhitelist(address user, uint amount) external {
        require(admin == msg.sender, "no admin");
        whitelist[user] = amount;
    }
    function adminSetWhitelistMulti(address[] calldata addresses, uint256[] calldata amounts) external {
        require(admin == msg.sender, "no admin");
        for(uint i=0; i < addresses.length; i++){
            whitelist[ addresses[i] ] = amounts[i];
        }
    }
    function adminSetWhitelistBlocks(uint start, uint end) external {
        require(admin == msg.sender, "no admin");
        whitelistStartBlock = start;
        whitelistEndBlock = end;
    }

    function adminSetPublicBlocks(uint start, uint end) external {
        require(admin == msg.sender, "no admin");
        publicStartBlock = start;
        publicEndBlock = end;
    }

    function adminSetClaimBlocks(uint start, uint end) external {
        require(admin == msg.sender, "no admin");
        claimStartBlock = start;
        claimEndBlock = end;
    }

    function adminSweepRemainingHRMS() external {
        require(admin == msg.sender, "no admin");
        require(whitelistEndBlock > block.number, "claim not ended");
        require(publicEndBlock > block.number, "claim not ended");
        preHermes.transfer(treasure, preHermes.balanceOf(address(this)));
    }

}
