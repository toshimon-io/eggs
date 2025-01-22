//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract EGGS is ERC20Burnable, Ownable2Step, ReentrancyGuard {
    address payable private FEE_ADDRESS;

    uint256 private constant MIN = 1000;

    uint16 public SELL_FEE = 975;
    uint16 public BUY_FEE = 990;
    uint16 public BUY_FEE_REVERSE = 10;
    uint16 private constant FEE_BASE_1000 = 1000;

    uint16 private constant FEES_BUY = 333;
    uint16 private constant FEES_SELL = 125;

    bool public start = false;

    uint128 private constant SONICinWEI = 1 * 10 ** 18;

    uint256 private totalBorrowed = 0;
    uint256 private totalCollateral = 0;

    uint128 public constant maxSupply = 10 ** 11 * SONICinWEI;
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
    event FeeAddressUpdated(address _address);
    event buyFeeUpdated(uint256 buyFee);
    event Started(bool started);
    event LoanDataUpdate(
        uint256 collateralByDate,
        uint256 borrowedByDate,
        uint256 totalBorrowed,
        uint256 totalCollateral
    );
    event SendSonic(address to, uint256 amount);

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
        emit Started(true);
    }

    function mint(address to, uint256 value) private {
        require(to != address(0x0), "Can't mint to to 0x0 address");
        totalMinted = totalMinted + value;
        require(totalMinted <= maxSupply, "NO MORE EGGS");

        _mint(to, value);
    }

    function setFeeAddress(address _address) external onlyOwner {
        require(
            _address != address(0x0),
            "Can't set fee address to 0x0 address"
        );
        FEE_ADDRESS = payable(_address);
        emit FeeAddressUpdated(_address);
    }

    function setBuyFee(uint16 amount) external onlyOwner {
        require(amount <= 1000, "buy fee must be less 0% or more");
        require(amount >= 990, "buy fee must be less than 1%");
        BUY_FEE = amount;
        emit buyFeeUpdated(amount);
    }
    function buy(address reciever) external payable nonReentrant {
        liquidate();
        require(start, "Trading must be initialized");
        require(msg.value > MIN, "must trade over min");
        require(reciever != address(0x0), "Reciever cannot be 0x0 address");

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
        uint256 feeAddressAmount = eggs / FEES_SELL;
        _burn(msg.sender, eggs - feeAddressAmount);

        // Payment to sender
        sendSonic(msg.sender, (sonic * SELL_FEE) / FEE_BASE_1000);

        // Team fee
        _transfer(msg.sender, FEE_ADDRESS, feeAddressAmount);

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

    function leverage(
        uint256 sonic,
        uint256 numberOfDays
    ) public payable nonReentrant {
        liquidate();

        Loan memory userLoan = Loans[msg.sender];
        if (userLoan.borrowed != 0) {
            if (isLoanExpired(msg.sender)) {
                delete Loans[msg.sender];
            }
            require(
                Loans[msg.sender].borrowed == 0,
                "Use account with no loans"
            );
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
        mint(FEE_ADDRESS, (eggsFee * 100) / 333);

        addLoansByDate(userSonic, userEggs, endDate);

        require(msg.value >= sonicFee, "Insufficient sonic fee sent");

        Loans[msg.sender] = Loan({
            collateral: userEggs,
            borrowed: (userSonic * 99) / 100,
            endDate: endDate
        });
        if (msg.value > sonicFee) {
            sendSonic(msg.sender, msg.value - sonicFee);
        }
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
        require(
            numberOfDays < 366,
            "Max borrow/extension must be 365 days or less"
        );
        require(sonic != 0, "Must borrow more than 0");
        if (isLoanExpired(msg.sender)) {
            delete Loans[msg.sender];
        }

        uint256 endDate = getMidnightTimestamp(
            (numberOfDays * 1 days) + block.timestamp
        );

        uint256 sonicFee = getInterestFeeInEggs(sonic, numberOfDays);

        uint256 userBorrowed = Loans[msg.sender].borrowed;
        uint256 userCollateral = Loans[msg.sender].collateral;

        if (userBorrowed != 0) {
            uint256 userEndDate = Loans[msg.sender].endDate;

            require(endDate >= userEndDate, "Cant decrease loan length");

            subLoansByDate(userBorrowed, userCollateral, userEndDate);
            uint256 additionalFee = getInterestFeeInEggs(
                userBorrowed,
                (endDate - userEndDate) / 1 days
            );
            sonicFee = sonicFee + additionalFee;
        }

        require(sonic > sonicFee, "You must borrow more than the fee");

        uint256 userSonic = sonic - sonicFee;
        uint256 userEggs = SONICtoEGGSNoTrade(sonic);
        uint256 eggsFee = SONICtoEGGSNoTrade(sonicFee);
        uint256 feeAddressFee = (eggsFee * 100) / 333;

        _transfer(msg.sender, address(this), userEggs);
        _transfer(address(this), FEE_ADDRESS, feeAddressFee);
        _burn(address(this), eggsFee - feeAddressFee);

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

    function removeCollateral(uint256 amount) public nonReentrant {
        liquidate();
        uint256 collateral = Loans[msg.sender].collateral;
        require(
            !isLoanExpired(msg.sender),
            "Your loan has been liquidated, no collateral to remove"
        );
        require(
            Loans[msg.sender].borrowed <=
                (EGGStoSONIC(collateral - amount) * 99) / 100,
            "Require 99% collateralization rate"
        );
        Loans[msg.sender].collateral = Loans[msg.sender].collateral - amount;
        _transfer(address(this), msg.sender, amount);
        subLoansByDate(0, amount, Loans[msg.sender].endDate);

        safetyCheck(0);
    }

    function closePosition() public payable nonReentrant {
        liquidate();
        uint256 borrowed = Loans[msg.sender].borrowed;
        uint256 collateral = Loans[msg.sender].collateral;
        require(
            !isLoanExpired(msg.sender),
            "Your loan has been liquidated, no collateral to remove"
        );
        require(borrowed == msg.value, "Must return entire borrowed amount");
        _transfer(address(this), msg.sender, collateral);
        subLoansByDate(borrowed, collateral, Loans[msg.sender].endDate);

        delete Loans[msg.sender];
        safetyCheck(0);
    }
    function flashClosePosition() public nonReentrant {
        liquidate();
        uint256 borrowed = Loans[msg.sender].borrowed;
        uint256 borrowedInEggs = SONICtoEGGSNoTrade(borrowed);
        uint256 collateral = Loans[msg.sender].collateral;

        require(
            !isLoanExpired(msg.sender),
            "Your loan has been liquidated, no collateral to remove"
        );

        uint256 collateralAfterFee = (collateral * 99) / 100;
        uint256 fee = collateral / 100;
        require(
            collateralAfterFee >= borrowedInEggs,
            "You do not have enough collateral to close position"
        );

        uint256 toUser = collateralAfterFee - borrowedInEggs;
        uint256 feeAddressFee = (fee * 100) / 333;

        _transfer(address(this), msg.sender, toUser);
        _transfer(address(this), FEE_ADDRESS, feeAddressFee);
        _burn(address(this), collateralAfterFee - toUser);
        _burn(address(this), fee - feeAddressFee);
        subLoansByDate(borrowed, collateral, Loans[msg.sender].endDate);

        delete Loans[msg.sender];
        safetyCheck(borrowed);
    }

    function extendLoan(
        uint256 numberOfDays
    ) public payable nonReentrant returns (uint256) {
        liquidate();
        uint256 oldEndDate = Loans[msg.sender].endDate;
        uint256 borrowed = Loans[msg.sender].borrowed;
        uint256 collateral = Loans[msg.sender].collateral;

        uint256 newEndDate = getMidnightTimestamp(
            oldEndDate + (numberOfDays * 1 days)
        );
        uint256 loanFee = getInterestFeeInEggs(borrowed, numberOfDays);
        require(
            !isLoanExpired(msg.sender),
            "Your loan has been liquidated, no collateral to remove"
        );
        require(loanFee == msg.value, "Loan extension fee incorrect");

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
            collateral = collateral + CollateralByDate[lastLiquidationDate];
            borrowed = borrowed + BorrowedByDate[lastLiquidationDate];
            lastLiquidationDate = lastLiquidationDate + 1 days;
        }
        if (collateral != 0) {
            totalCollateral = totalCollateral - collateral;
            _burn(address(this), collateral);
        }
        if (borrowed != 0) {
            totalBorrowed = totalBorrowed - borrowed;
            safetyCheck(borrowed);
        }
    }

    function addLoansByDate(
        uint256 borrowed,
        uint256 collateral,
        uint256 date
    ) private {
        CollateralByDate[date] = CollateralByDate[date] + collateral;
        BorrowedByDate[date] = BorrowedByDate[date] + borrowed;
        totalBorrowed = totalBorrowed + borrowed;
        totalCollateral = totalCollateral + collateral;
        emit LoanDataUpdate(
            CollateralByDate[date],
            BorrowedByDate[date],
            totalBorrowed,
            totalCollateral
        );
    }
    function subLoansByDate(
        uint256 borrowed,
        uint256 collateral,
        uint256 date
    ) private {
        CollateralByDate[date] = CollateralByDate[date] - collateral;
        BorrowedByDate[date] = BorrowedByDate[date] - borrowed;
        totalBorrowed = totalBorrowed - borrowed;
        totalCollateral = totalCollateral - collateral;
        emit LoanDataUpdate(
            CollateralByDate[date],
            BorrowedByDate[date],
            totalBorrowed,
            totalCollateral
        );
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
        require(
            _totalColateral >= totalCollateral,
            "The eggs balance of the contract must be greater than or equal to the collateral"
        );
        require(lastPrice <= newPrice, "The price of eggs cannot decrease");
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
        emit SendSonic(_address, _value);
    }

    //utils
    function getBuyEggs(uint256 amount) external view returns (uint256) {
        return
            (amount * (totalSupply()) * (BUY_FEE)) /
            (getBacking()) /
            (FEE_BASE_1000);
    }

    receive() external payable {}

    fallback() external payable {}
}
