//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract EGGS is ERC20Burnable, Ownable, ReentrancyGuard {
    address payable private FEE_ADDRESS;

    uint256 public constant MIN = 1000;

    uint16 public SELL_FEE = 975;
    uint16 public BUY_FEE = 990;
    uint16 public BUY_FEE_REVERSE = 10;
    uint16 public constant FEE_BASE_1000 = 1000;

    uint16 public constant FEES_BUY = 333;
    uint16 public constant FEES_SELL = 80;

    bool public start = false;

    uint128 public constant SONICinWEI = 1 * 10 ** 18;

    uint256 private totalBorrowed = 0;
    uint256 private totalCollateral = 0;

    uint256 public LoanFEEMax = 200 * SONICinWEI;
    uint256 public LoanFEEMin = 175 * SONICinWEI;
    uint128 public constant maxSupply = 100000000000 * SONICinWEI;
    uint256 public totalMinted;
    uint256 public lastPrice = 0;

    struct Loan {
        uint256 collateral; // shares of token staked
        uint256 borrowed; // user reward per token paid
        uint256 endDate;
    }

    mapping(address => Loan) public Loans;

    mapping(uint256 => uint256) public BorrowedByDate;
    mapping(uint256 => uint256) public CollateralByDate;
    uint256 public lastLiquidationDate;
    event Price(uint256 time, uint256 price, uint256 volumeInSonic);
    event MaxUpdated(uint256 max);
    event SellFeeUpdated(uint256 sellFee);
    event buyFeeUpdated(uint256 buyFee);

    constructor() payable ERC20("Eggs", "EGGS") Ownable(msg.sender) {
        lastLiquidationDate = getMidnightTimestamp(block.timestamp);
        mint(msg.sender, msg.value * MIN);
        mint(address(this), 10000);
        _transfer(
            address(this),
            0x000000000000000000000000000000000000dEaD,
            10000
        );
    }
    function setStart() public onlyOwner {
        start = true;
    }

    function mint(address to, uint256 value) private {
        require(totalMinted <= maxSupply, "NO MORE EGGS");
        totalMinted += value;
        _mint(to, value);
    }

    //Will be set to 100m eth value after 1 hr
    function setMax(uint256 _max) public onlyOwner {
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
    function buy(
        address reciever
    ) external payable nonReentrant returns (uint256) {
        liquidate();
        require(start);
        require(msg.value > MIN, "must trade over min");

        // Mint Eggs to sender
        uint256 eggs = SONICtoEGGS(msg.value);

        mint(reciever, (eggs * getBuyFee()) / FEE_BASE_1000);

        // Team fee
        mint(FEE_ADDRESS, eggs / FEES_BUY);

        safetyCheck(msg.value);
    }
    function sell(uint256 eggs) external nonReentrant {
        require(eggs > MIN, "must trade over min");
        liquidate();

        // Total Eth to be sent
        uint256 sonic = EGGStoSONIC(eggs);

        // Burn of JAY
        _burn(msg.sender, eggs);

        // Payment to sender
        sendSonic(msg.sender, (sonic * SELL_FEE) / FEE_BASE_1000);

        // Team fee
        sendSonic(FEE_ADDRESS, sonic / FEES_SELL);

        safetyCheck(sonic);
    }
    function getBuyAmount(uint256 amount) public view returns (uint256) {
        uint256 eggs = SONICtoEGGSNoTrade(amount);
        return ((eggs * getBuyFee()) / FEE_BASE_1000);
    }
    function leverageFee(
        uint256 eggs,
        uint256 numberOfDays
    ) public view returns (uint256) {
        uint256 mintFee = (eggs * BUY_FEE_REVERSE) / FEE_BASE_1000;

        uint256 interest = getInterestFeeInEggs(eggs, numberOfDays);

        return (mintFee + interest);
    }

    function leverage(uint256 sonic, uint256 numberOfDays) public payable {
        liquidate();

        Loan memory userLoan = Loans[msg.sender];
        if (userLoan.borrowed > 0) {
            if (isLoanExpired(msg.sender)) {
                delete Loans[msg.sender];
            }
            require(Loans[msg.sender].borrowed == 0, "Use account w no loans");
        }
        uint256 endDate = getMidnightTimestamp(
            (numberOfDays * 1 days) + block.timestamp
        );

        uint256 sonicFee = leverageFee(sonic, numberOfDays);

        uint256 userSonic = sonic - sonicFee;

        uint256 subValue = (sonicFee * 1) / 5;

        uint256 userEggs = SONICtoEGGSLev(userSonic, subValue);
        uint256 eggsFee = SONICtoEGGSLev(sonicFee, subValue);
        mint(address(this), userEggs);
        mint(FEE_ADDRESS, (eggsFee * 1) / 5);

        addLoansByDate(userSonic, userEggs, endDate);

        require(msg.value >= sonicFee, "hey");

        Loans[msg.sender] = Loan({
            collateral: userEggs,
            borrowed: (userSonic * 99) / 100,
            endDate: endDate
        });

        safetyCheck(sonic);
    }

    function getInterestFeeInEggs(
        uint256 amount,
        uint256 numberOfDays
    ) public pure returns (uint256) {
        uint256 interest = ((3900 * numberOfDays) / 365) + 100;
        return ((amount * interest) / 100 / FEE_BASE_1000);
    }

    function borrow(uint256 sonic, uint256 numberOfDays) public {
        liquidate();
        require(numberOfDays < 366 && sonic > 0);

        if (isLoanExpired(msg.sender)) {
            delete Loans[msg.sender];
        }

        uint256 endDate = getMidnightTimestamp(
            (numberOfDays * 1 days) + block.timestamp
        );

        uint256 sonicFee = getInterestFeeInEggs(sonic, numberOfDays);

        uint256 userBorrowed = Loans[msg.sender].borrowed;
        uint256 userCollateral = Loans[msg.sender].collateral;

        if (userBorrowed > 0) {
            uint256 userEndDate = Loans[msg.sender].endDate;

            require(endDate >= userEndDate, "Cant decrease loan length");

            subLoansByDate(userBorrowed, userCollateral, userEndDate);
            uint256 additionalFee = getInterestFeeInEggs(
                userBorrowed,
                (endDate - userEndDate) / 1 days
            );
            sonicFee += additionalFee;
        }

        require(sonic > sonicFee, "Hey");

        uint256 userSonic = sonic - sonicFee;
        uint256 userEggs = SONICtoEGGSNoTrade(sonic);
        uint256 eggsFee = SONICtoEGGSNoTrade(sonicFee);

        _transfer(msg.sender, address(this), userEggs);
        _transfer(address(this), FEE_ADDRESS, (eggsFee * 2) / 5);
        _burn(address(this), (eggsFee * 3) / 5);

        uint256 newUserBorrow = (userSonic * 99) / 100;
        sendSonic(msg.sender, newUserBorrow);

        uint256 newUserCollateral = userEggs - eggsFee + userCollateral;
        uint256 newUserBorrowTotal = newUserBorrow + userBorrowed;
        addLoansByDate(newUserBorrowTotal, newUserCollateral, endDate);

        Loans[msg.sender] = Loan({
            collateral: newUserCollateral,
            borrowed: newUserBorrowTotal,
            endDate: endDate
        });

        safetyCheck(sonicFee);
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
                (EGGStoSONIC(collateral - amount) * 99) / 100,
            ""
        );
        Loans[msg.sender].collateral -= amount;
        _transfer(address(this), msg.sender, amount);
        subLoansByDate(0, amount, Loans[msg.sender].endDate);

        safetyCheck(0);
    }

    function closePosition() public payable {
        liquidate();
        uint256 borrowed = Loans[msg.sender].borrowed;
        uint256 collateral = Loans[msg.sender].collateral;
        require(!isLoanExpired(msg.sender) && borrowed == msg.value);
        _transfer(address(this), msg.sender, collateral);
        subLoansByDate(borrowed, collateral, Loans[msg.sender].endDate);

        delete Loans[msg.sender];
        safetyCheck(0);
    }
    function flashClosePosition() public {
        liquidate();
        uint256 borrowed = Loans[msg.sender].borrowed;
        uint256 borrowedInEggs = SONICtoEGGSNoTrade(borrowed);
        uint256 collateral = Loans[msg.sender].collateral;

        require(!isLoanExpired(msg.sender));

        uint256 collateralAfterFee = (collateral * 99) / 100;
        uint256 fee = collateral / 100;
        require(collateralAfterFee >= borrowedInEggs, "OH no");

        uint256 toUser = collateralAfterFee - borrowedInEggs;
        _transfer(address(this), msg.sender, toUser);
        _transfer(address(this), FEE_ADDRESS, fee / 3);
        _burn(address(this), collateralAfterFee - toUser);
        _burn(address(this), (fee * 2) / 3);
        subLoansByDate(borrowed, collateral, Loans[msg.sender].endDate);

        delete Loans[msg.sender];
        safetyCheck(borrowed);
    }

    function extendLoan(uint256 numberOfDays) public payable returns (uint256) {
        liquidate();
        uint256 oldEndDate = Loans[msg.sender].endDate;
        uint256 borrowed = Loans[msg.sender].borrowed;
        uint256 collateral = Loans[msg.sender].collateral;

        uint256 newEndDate = getMidnightTimestamp(
            oldEndDate + (numberOfDays * 1 days)
        );
        uint256 loanFee = getInterestFeeInEggs(borrowed, numberOfDays);
        require(!isLoanExpired(msg.sender) && loanFee == msg.value);

        subLoansByDate(borrowed, collateral, oldEndDate);
        addLoansByDate(borrowed, collateral, newEndDate);
        Loans[msg.sender].endDate = newEndDate;

        safetyCheck(msg.value);
        return loanFee;
    }

    function liquidate() public {
        uint256 borrowed;
        uint256 collateral;

        while (lastLiquidationDate < block.timestamp) {
            lastLiquidationDate = lastLiquidationDate + 1 days;
            collateral += CollateralByDate[lastLiquidationDate];
            borrowed += BorrowedByDate[lastLiquidationDate];
        }
        if (collateral > 0) {
            _burn(address(this), collateral);
        }
        if (borrowed > 0) {
            totalBorrowed -= borrowed;
            safetyCheck(borrowed);
        }
    }

    function addLoansByDate(
        uint256 borrowed,
        uint256 collateral,
        uint256 date
    ) private {
        CollateralByDate[date] += collateral;
        BorrowedByDate[date] += borrowed;
        totalBorrowed += borrowed;
        totalCollateral += collateral;
    }
    function subLoansByDate(
        uint256 borrowed,
        uint256 collateral,
        uint256 date
    ) private {
        CollateralByDate[date] -= collateral;
        BorrowedByDate[date] -= borrowed;
        totalBorrowed -= borrowed;
        totalCollateral -= collateral;
    }

    // utility fxns
    function getMidnightTimestamp(uint256 date) public pure returns (uint256) {
        uint256 midnightTimestamp = date - (date % 86400); // Subtracting the remainder when divided by the number of seconds in a day (86400)
        return midnightTimestamp + 1 days;
    }

    function getLoansExpiringByDate(
        uint256 date
    ) public view returns (uint256, uint256) {
        return (
            BorrowedByDate[getMidnightTimestamp(date)],
            CollateralByDate[getMidnightTimestamp(date)]
        );
    }

    function getLoanByAddress(
        address _address
    ) public view returns (uint256, uint256, uint256) {
        if (Loans[_address].endDate >= block.timestamp) {
            return (
                Loans[_address].collateral,
                Loans[_address].borrowed,
                Loans[_address].endDate
            );
        } else {
            return (0, 0, 0);
        }
    }

    function isLoanExpired(address _address) public view returns (bool) {
        return Loans[_address].endDate < block.timestamp;
    }

    function getBuyFee() public view returns (uint256) {
        return BUY_FEE;
    }

    // Buy Eggs

    function getTotalBorrowed() public view returns (uint256) {
        return totalBorrowed;
    }

    function getTotalCollateral() public view returns (uint256) {
        return totalCollateral;
    }

    function getBacking() public view returns (uint256) {
        return address(this).balance + getTotalBorrowed();
    }

    function safetyCheck(uint256 soinc) private {
        uint256 newPrice = (getBacking() * 1 ether) / totalSupply();
        uint256 _totalColateral = balanceOf(address(this));
        uint256 _totalBorrowed = getTotalBorrowed();
        require(_totalColateral >= totalCollateral, "hey fuck you");
        require(lastPrice <= newPrice, "heyy fuck you");
        lastPrice = newPrice;
        emit Price(block.timestamp, newPrice, soinc);
    }
    function EGGStoSONICLev(
        uint256 value,
        uint256 msg_value
    ) public view returns (uint256) {
        return (value * (getBacking() - msg_value)) / (totalSupply());
    }
    function EGGStoSONIC(uint256 value) public view returns (uint256) {
        return (value * getBacking()) / totalSupply();
    }

    function SONICtoEGGS(uint256 value) public view returns (uint256) {
        return (value * totalSupply()) / (getBacking() - value);
    }

    function SONICtoEGGSLev(
        uint256 value,
        uint256 fee
    ) public view returns (uint256) {
        return (value * totalSupply()) / (getBacking() - fee);
    }

    function SONICtoEGGSNoTrade(uint256 value) public view returns (uint256) {
        return (value * totalSupply()) / (getBacking());
    }

    function sendSonic(address _address, uint256 _value) internal {
        (bool success, ) = _address.call{value: _value}("");
        require(success, "SONIC Transfer failed.");
    }

    //utils
    function getBuyEggs(uint256 amount) external view returns (uint256) {
        return
            (amount * (totalSupply()) * (BUY_FEE)) /
            (getBacking()) /
            (FEE_BASE_1000);
    }

    function deposit() public payable {}

    receive() external payable {}

    fallback() external payable {}
}
