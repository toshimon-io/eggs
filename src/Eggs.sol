//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract JAY is ERC20Burnable, Ownable, ReentrancyGuard {
    address payable private FEE_ADDRESS;

    uint256 public constant MIN = 1000;
    uint256 public MAX = 1 * 10 ** 28;

    uint16 public SELL_FEE = 900;
    uint16 public BUY_FEE = 900;
    uint16 public constant FEE_BASE_1000 = 1000;

    uint8 public constant FEES = 33;

    bool public start = false;

    uint128 public constant ETHinWEI = 1 * 10 ** 18;

    uint256 private totalBorrowed = 0;

    //lending

    uint256 public LoanFEEMax = 200 * ETHinWEI;
    uint256 public LoanFEEMin = 175 * ETHinWEI;
    uint128 public constant MAX_BACKING = 33333 * ETHinWEI;

    struct Loan {
        uint256 collateral; // shares of token staked
        uint256 borrowed; // user reward per token paid
        uint256 endDate;
        uint256 borrowedInJay;
    }

    mapping(address => Loan) public Loans;

    mapping(uint256 => uint256) public LoansByDate;
    uint256 public lastLiquidationDate;
    event Price(uint256 time, uint256 recieved, uint256 sent);
    event MaxUpdated(uint256 max);
    event SellFeeUpdated(uint256 sellFee);
    event buyFeeUpdated(uint256 buyFee);

    constructor() payable ERC20("JayPeggers", "JAY") {
        _mint(msg.sender, msg.value * MIN);
        transfer(0x000000000000000000000000000000000000dEaD, 10000);
    }
    function setStart() public onlyOwner {
        start = true;
    }

    //Will be set to 100m eth value after 1 hr
    function setMax(uint256 _max) public onlyOwner {
        MAX = _max;
        emit MaxUpdated(_max);
    }
    function setFeeAddress(address _address) external onlyOwner {
        require(_address != address(0x0));
        FEE_ADDRESS = payable(_address);
    }

    function setBuyFee(uint16 amount) external onlyOwner {
        require(amount <= 969 && amount >= 10);
        BUY_FEE = amount;
        emit buyFeeUpdated(amount);
    }
    function buy(address reciever) external payable nonReentrant {
        liquidate();
        require(start);
        //require(msg.value > MIN && msg.value < MAX, "must trade over min");

        // Mint Jay to sender
        uint256 jay = ETHtoJAY(msg.value);
        _mint(reciever, (jay * getBuyFee()) / FEE_BASE_1000);

        // Team fee
        // sendEth(FEE_ADDRESS, msg.value / FEES);

        emit Price(block.timestamp, jay, msg.value);
    }
    function borrow(
        uint256 jayCollateral,
        uint256 ethToBorrow,
        uint256 numberOfDays
    ) public {
        liquidate();
        require(numberOfDays < 366);
        uint256 interst = ((LoanFEEMax - ((numberOfDays * LoanFEEMin) / 365)) *
            numberOfDays) / 365;
        uint256 fee = ETHtoJAYNoTrade(
            (ethToBorrow * interst) / ETHinWEI / FEE_BASE_1000
        );
        uint256 endDate = getMidnightTimestamp(
            (numberOfDays * 1 days) + block.timestamp
        );

        if (Loans[msg.sender].borrowed > 0) {
            require(
                Loans[msg.sender].endDate >= block.timestamp,
                "youre in default!"
            );
            require(
                endDate >= Loans[msg.sender].endDate,
                "Cant decrease loan length"
            );

            if (numberOfDays != 0) {
                uint256 additionalTime = endDate - Loans[msg.sender].endDate;
                fee += getLoanFee(additionalTime);
            }
        }

        require(endDate - block.timestamp >= 1 days, "min 1 day");

        uint256 collateral = jayCollateral + Loans[msg.sender].collateral - fee;
        uint256 borrowAmount = ethToBorrow + Loans[msg.sender].borrowed;
        uint256 borrowAmountInJay = ETHtoJAYNoTrade(borrowAmount);

        require(
            (collateral * 97) / 100 >= ETHtoJAYNoTrade(borrowAmount),
            "You cant borrow that much"
        );

        Loans[msg.sender] = Loan({
            collateral: collateral,
            borrowed: borrowAmount,
            endDate: endDate,
            borrowedInJay: borrowAmountInJay
        });

        if (jayCollateral > 0)
            _transfer(msg.sender, address(this), jayCollateral);
        _burn(address(this), (fee * 4) / 5);
        _transfer(address(this), FEE_ADDRESS, (fee * 1) / 5);
        if (ethToBorrow > 0) sendEth(msg.sender, ethToBorrow);
        totalBorrowed += ethToBorrow;
        updateLoansByDate(borrowAmountInJay);
    }
    function repay() public payable {
        liquidate();
        require(
            !isLoanExpired(msg.sender) &&
                msg.value <= Loans[msg.sender].borrowed
        );
        Loans[msg.sender].borrowed -= msg.value;
        totalBorrowed -= msg.value;
        updateLoansByDate(totalBorrowed);
    }

    function removeCollateral(uint256 amount) public {
        liquidate();
        uint256 collateral = Loans[msg.sender].collateral;
        require(
            amount <= collateral && !isLoanExpired(msg.sender),
            "you dont have enough tokens"
        );
        require(
            Loans[msg.sender].borrowed <=
                (JAYtoETH(collateral - amount) * 95) / 100,
            ""
        );
        Loans[msg.sender].collateral -= collateral;
        transfer(msg.sender, collateral);
        updateLoansByDate(Loans[msg.sender].borrowed);
    }

    function closePosition() public payable {
        liquidate();
        uint256 borrowed = Loans[msg.sender].borrowed;
        uint256 collateral = Loans[msg.sender].collateral;
        require(!isLoanExpired(msg.sender) && borrowed == msg.value);
        transfer(msg.sender, collateral);
        delete Loans[msg.sender];
        totalBorrowed -= msg.value;
        updateLoansByDate(0);
    }

    function extendLoan(uint256 numberOfDays) public payable returns (uint256) {
        liquidate();
        uint256 loanFee = getLoanFee(numberOfDays);
        require(!isLoanExpired(msg.sender) && loanFee == msg.value);
        Loans[msg.sender].endDate = getMidnightTimestamp(
            block.timestamp + (numberOfDays * 1 days)
        );

        return loanFee;
    }

    function liquidate() public {
        uint256 total;
        while (lastLiquidationDate < block.timestamp) {
            lastLiquidationDate = lastLiquidationDate + 1 days;
            total += LoansByDate[lastLiquidationDate];
        }
        if (total > 0) {
            _burn(address(this), total);
        }
    }

    function updateLoansByDate(uint256 amount) private {
        LoansByDate[Loans[msg.sender].endDate] -= Loans[msg.sender]
            .borrowedInJay;
        if (amount > 0) {
            LoansByDate[Loans[msg.sender].endDate] += ETHtoJAYNoTrade(amount);
        }
    }

    // utility fxns
    function getMidnightTimestamp(uint256 date) public pure returns (uint256) {
        uint256 midnightTimestamp = date - (date % 86400); // Subtracting the remainder when divided by the number of seconds in a day (86400)
        return midnightTimestamp;
    }

    function getLoansExpiringByDate(
        uint256 date
    ) public view returns (uint256) {
        return LoansByDate[getMidnightTimestamp(date)];
    }

    function getLoanByAddress(
        address _address
    ) public view returns (Loan memory) {
        return Loans[_address];
    }

    function getLoanFee(uint256 numberOfDays) public view returns (uint256) {
        uint256 interst = ((LoanFEEMax - ((numberOfDays * LoanFEEMin) / 365)) *
            numberOfDays) / 365;

        return
            (Loans[msg.sender].borrowed * interst) /
            numberOfDays /
            ETHinWEI /
            FEE_BASE_1000;
    }

    function isLoanExpired(address _address) public view returns (bool) {
        return Loans[_address].endDate < block.timestamp;
    }

    function getBuyFee() public view returns (uint256) {
        return BUY_FEE;
    }

    // Buy Jay

    function getTotalBorrowed() public view returns (uint256) {
        return totalBorrowed;
    }

    function getBacking() public view returns (uint256) {
        return address(this).balance + getTotalBorrowed();
    }

    function JAYtoETH(uint256 value) public view returns (uint256) {
        return (value * getBacking()) / totalSupply();
    }

    function ETHtoJAY(uint256 value) public view returns (uint256) {
        return (value * totalSupply()) / (getBacking() - value);
    }

    function ETHtoJAYNoTrade(uint256 value) public view returns (uint256) {
        return (value * totalSupply()) / (getBacking());
    }

    function sendEth(address _address, uint256 _value) internal {
        (bool success, ) = _address.call{value: _value}("");
        require(success, "ETH Transfer failed.");
    }

    //utils
    function getBuyJay(uint256 amount) external view returns (uint256) {
        return
            (amount * (totalSupply()) * (BUY_FEE)) /
            (getBacking()) /
            (FEE_BASE_1000);
    }

    function deposit() public payable {}

    receive() external payable {}

    fallback() external payable {}
}
