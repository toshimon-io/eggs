//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract EGGS is ERC20Burnable, Ownable2Step, ReentrancyGuard {
    address payable private FEE_ADDRESS;

    uint256 private constant MIN = 1000;

    uint16 public SELL_FEE = 975;
    uint16 public BUY_FEE = 975;
    uint16 public BUY_FEE_REVERSE = 10;
    uint16 private constant FEE_BASE_1000 = 1000;

    uint16 private constant FEES_BUY = 125;
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
        uint256 numberOfDays;
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
    event Liquidate(uint256 time, uint256 amount);
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
        require(FEE_ADDRESS != address(0x0), "Must set fee address");
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
        require(amount >= 975, "buy fee must be less than 2.5%");
        BUY_FEE = amount;
        emit buyFeeUpdated(amount);
    }
    function buy(address reciever) external payable nonReentrant {
        liquidate();
        require(start, "Trading must be initialized");

        require(reciever != address(0x0), "Reciever cannot be 0x0 address");

        // Mint Eggs to sender
        uint256 eggs = SONICtoEGGS(msg.value);

        mint(reciever, (eggs * getBuyFee()) / FEE_BASE_1000);

        // Team fee
        uint256 feeAddressAmount = msg.value / FEES_BUY;
        require(feeAddressAmount > MIN, "must trade over min");
        sendSonic(FEE_ADDRESS, feeAddressAmount);

        safetyCheck(msg.value);
    }
    function sell(uint256 eggs) external nonReentrant {
        liquidate();

        // Total Eth to be sent
        uint256 sonic = EGGStoSONIC(eggs);

        // Burn of JAY
        uint256 feeAddressAmount = sonic / FEES_SELL;
        _burn(msg.sender, eggs);

        // Payment to sender
        sendSonic(msg.sender, (sonic * SELL_FEE) / FEE_BASE_1000);

        // Team fee

        require(feeAddressAmount > MIN, "must trade over min");
        sendSonic(FEE_ADDRESS, feeAddressAmount);

        safetyCheck(sonic);
    }
    function getBuyAmount(uint256 amount) public view returns (uint256) {
        uint256 eggs = SONICtoEGGSNoTrade(amount);
        return ((eggs * getBuyFee()) / FEE_BASE_1000);
    }
    function leverageFee(
        uint256 sonic,
        uint256 numberOfDays
    ) public view returns (uint256) {
        uint256 mintFee = (sonic * BUY_FEE_REVERSE) / FEE_BASE_1000;

        uint256 interest = getInterestFeeInEggs(sonic, numberOfDays);

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

        uint256 subValue = ((sonicFee * 3) / 10) + (userSonic / 100);
        uint256 totalFee = (sonicFee + userSonic / 100);
        uint256 feeOverage;
        if (msg.value > totalFee) {
            feeOverage = msg.value - totalFee;
            sendSonic(msg.sender, feeOverage);
        }
        require(
            msg.value - feeOverage == totalFee,
            "Insufficient sonic fee sent"
        );
        uint256 userEggs = SONICtoEGGSLev(userSonic, subValue);
        mint(address(this), userEggs);
        uint256 feeAddressAmount = (sonicFee * 3) / 10;
        require(feeAddressAmount > MIN, "Fees must be higher than min.");
        sendSonic(FEE_ADDRESS, feeAddressAmount);

        uint256 userBorrow = (userSonic * 99) / 100;

        addLoansByDate(userBorrow, userEggs, endDate);
        Loans[msg.sender] = Loan({
            collateral: userEggs,
            borrowed: userBorrow,
            endDate: endDate,
            numberOfDays: numberOfDays
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

    function borrow(uint256 sonic, uint256 numberOfDays) public nonReentrant {
        liquidate();
        require(
            numberOfDays < 366,
            "Max borrow/extension must be 365 days or less"
        );
        require(sonic != 0, "Must borrow more than 0");
        if (isLoanExpired(msg.sender)) {
            delete Loans[msg.sender];
        }
        require(
            Loans[msg.sender].borrowed == 0,
            "Use borrowMore to borrow more"
        );
        uint256 endDate = getMidnightTimestamp(
            (numberOfDays * 1 days) + block.timestamp
        );

        uint256 sonicFee = getInterestFeeInEggs(sonic, numberOfDays);

        uint256 feeAddressFee = (sonicFee * 3) / 10;

        uint256 userEggs = SONICtoEGGSNoTrade(sonic);
        _transfer(msg.sender, address(this), userEggs);
        require(feeAddressFee > MIN, "Fees must be higher than min.");

        uint256 newUserBorrow = (sonic * 99) / 100;

        sendSonic(msg.sender, newUserBorrow - sonicFee);
        sendSonic(FEE_ADDRESS, feeAddressFee);

        addLoansByDate(newUserBorrow, userEggs, endDate);

        Loans[msg.sender] = Loan({
            collateral: userEggs,
            borrowed: newUserBorrow,
            endDate: endDate,
            numberOfDays: numberOfDays
        });

        safetyCheck(sonicFee);
    }
    function borrowMore(uint256 sonic) public nonReentrant {
        liquidate();
        require(!isLoanExpired(msg.sender), "Loan expired use borrow");
        require(sonic != 0, "Must borrow more than 0");

        uint256 userBorrowed = Loans[msg.sender].borrowed;
        uint256 userCollateral = Loans[msg.sender].collateral;
        uint256 userEndDate = Loans[msg.sender].endDate;

        uint256 todayMidnight = getMidnightTimestamp(block.timestamp);
        uint256 newBorrowLength = (userEndDate - todayMidnight) / 1 days;

        uint256 sonicFee = getInterestFeeInEggs(sonic, newBorrowLength);

        uint256 userEggs = SONICtoEGGSNoTrade(sonic);
        uint256 userBorrowedInEggs = SONICtoEGGSNoTrade(userBorrowed);
        uint256 userExcessInEggs = ((userCollateral) * 99) /
            100 -
            userBorrowedInEggs;

        uint256 requireCollateralFromUser = userEggs;
        if (userExcessInEggs >= userEggs) {
            requireCollateralFromUser = 0;
        } else {
            requireCollateralFromUser =
                requireCollateralFromUser -
                userExcessInEggs;
        }

        if (requireCollateralFromUser != 0) {
            _transfer(msg.sender, address(this), requireCollateralFromUser);
        }

        uint256 feeAddressFee = (sonicFee * 3) / 10;

        uint256 newUserBorrow = (sonic * 99) / 100;

        uint256 newUserBorrowTotal = userBorrowed + newUserBorrow;
        uint256 newUserCollateralTotal = userCollateral +
            requireCollateralFromUser;

        require(feeAddressFee > MIN, "Fees must be higher than min.");
        sendSonic(FEE_ADDRESS, feeAddressFee);
        sendSonic(msg.sender, newUserBorrow - sonicFee);

        addLoansByDate(newUserBorrow, requireCollateralFromUser, userEndDate);

        Loans[msg.sender] = Loan({
            collateral: newUserCollateralTotal,
            borrowed: newUserBorrowTotal,
            endDate: userEndDate,
            numberOfDays: newBorrowLength
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
    function repay() public payable nonReentrant {
        liquidate();

        uint256 borrowed = Loans[msg.sender].borrowed;
        require(borrowed > msg.value, "Must repay less than borrowed amount");
        require(msg.value != 0, "Must repay something");

        require(
            !isLoanExpired(msg.sender),
            "Your loan has been liquidated, cannot repay"
        );
        uint256 newBorrow = borrowed - msg.value;
        Loans[msg.sender].borrowed = newBorrow;
        subLoansByDate(msg.value, 0, Loans[msg.sender].endDate);

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

        uint256 collateral = Loans[msg.sender].collateral;
        uint256 collateralInSonic = EGGStoSONIC(collateral);
        _burn(address(this), collateral);
        require(
            !isLoanExpired(msg.sender),
            "Your loan has been liquidated, no collateral to remove"
        );

        uint256 collateralInSonicAfterFee = (collateralInSonic * 99) / 100;

        uint256 fee = collateralInSonic / 100;
        require(
            collateralInSonicAfterFee >= borrowed,
            "You do not have enough collateral to close position"
        );

        uint256 toUser = collateralInSonicAfterFee - borrowed;
        uint256 feeAddressFee = (fee * 3) / 10;

        sendSonic(msg.sender, toUser);

        require(feeAddressFee > MIN, "Fees must be higher than min.");
        sendSonic(FEE_ADDRESS, feeAddressFee);
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
        uint256 _numberOfDays = Loans[msg.sender].numberOfDays;

        uint256 newEndDate = oldEndDate + (numberOfDays * 1 days);

        uint256 loanFee = getInterestFeeInEggs(borrowed, numberOfDays);
        require(
            !isLoanExpired(msg.sender),
            "Your loan has been liquidated, no collateral to remove"
        );
        require(loanFee == msg.value, "Loan extension fee incorrect");
        uint256 feeAddressFee = (loanFee * 3) / 10;
        require(feeAddressFee > MIN, "Fees must be higher than min.");
        sendSonic(FEE_ADDRESS, feeAddressFee);
        subLoansByDate(borrowed, collateral, oldEndDate);
        addLoansByDate(borrowed, collateral, newEndDate);
        Loans[msg.sender].endDate = newEndDate;
        Loans[msg.sender].numberOfDays = numberOfDays + _numberOfDays;
        require(
            (newEndDate - block.timestamp) / 1 days < 366,
            "Loan must be under 365 days"
        );

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
            emit Liquidate(lastLiquidationDate - 1 days, borrowed);
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

    function safetyCheck(uint256 sonic) private {
        uint256 newPrice = (getBacking() * 1 ether) / totalSupply();
        uint256 _totalColateral = balanceOf(address(this));
        require(
            _totalColateral >= totalCollateral,
            "The eggs balance of the contract must be greater than or equal to the collateral"
        );
        require(lastPrice <= newPrice, "The price of eggs cannot decrease");
        lastPrice = newPrice;
        emit Price(block.timestamp, newPrice, sonic);
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
    function SONICtoEGGSBorrow(
        uint256 value,
        uint256 fee
    ) public view returns (uint256) {
        return (value * totalSupply()) / (getBacking() + fee);
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
