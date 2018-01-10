pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract AccessCtl is Ownable {
    uint256 constant SUPPLYER = 0x1;
    uint256 constant CUSTOMER = 0x10;
    uint256 constant ADMIN = 0x100;

    struct Record {
        uint256 recordId;
        uint256 stockId;
        uint256 timestamp;
        uint256 amount;
        uint256 remain;
        address supplyer;
        uint256 nextRecordId;
    }

    struct Stock {
        uint256 stockId;
        string name;
        uint256 totalRemain;
        uint256 lastRecordId;
        uint256 lastSelledRecordId;
        uint256 price;
    }

    mapping (address => uint256) public licenses;
    mapping (address => uint256) public balances;
    mapping (uint256 => Record) public records;
    mapping (uint256 => Stock) public stocks;
    uint256 public recordAmount;
    uint256 public stockAmount;

    event NewRecord(uint256 recordId, uint256 stockId, uint256 totalRemain);
    event NewStock(uint256 stockId, string name, uint256 price);
    event StockArrival(uint256 stockId, uint256 amount, uint256 index);
    event StockShortage(uint256 stockId, uint256 amount);
    event Selled(uint256 stockId, uint256 amount, uint256 totalRemain);

    function checkLicense(uint256 license, uint256 flag) view returns (bool) {
        return license & flag == flag;
    }

    function setLicese (address _address, uint256 license) public {
        require (msg.sender == owner || checkLicense(licenses[msg.sender], ADMIN));
        require (msg.sender == owner || !checkLicense(license, ADMIN));
        licenses[_address] = license;
    }

    function newRecord (uint256 stockId, uint256 amount) {
        require (checkLicense(licenses[msg.sender], SUPPLYER));
        require (stockId <= stockAmount);
        recordAmount += 1;
        Record memory temp;
        temp.recordId = recordAmount;
        temp.stockId = stockId;
        temp.timestamp = now;
        temp.amount = amount;
        temp.remain = amount;
        temp.supplyer = msg.sender;
        records[temp.recordId] = temp;
        uint256 lastSelled = stocks[stockId].lastSelledRecordId;
        if (lastSelled == 0) {
            stocks[stockId].lastSelledRecordId = temp.recordId;
        }
        uint256 temptemp = stocks[stockId].lastRecordId;
        if (temptemp != 0) {
            records[temptemp].nextRecordId = temp.recordId;
        }
        stocks[stockId].lastRecordId = temp.recordId;
        stocks[stockId].totalRemain += amount;
        NewRecord(temp.recordId, temp.stockId, stocks[stockId].totalRemain);
    }

    function newStock (string name, uint256 price) {
        require (msg.sender == owner || checkLicense(licenses[msg.sender], SUPPLYER));
        stockAmount += 1;
        Stock memory temp;
        temp.name = name;
        temp.stockId = stockAmount;
        temp.totalRemain = 0;
        temp.lastRecordId = 0;
        temp.price = price;
        stocks[temp.stockId] = temp;
        NewStock(temp.stockId, name, price);
    }

    function restock (uint256 stockId, uint256 amount, uint256 index) {
        StockArrival(stockId, amount, index);
        newRecord(stockId, amount);
    }

    function sell (uint256 stockId, uint256 _amount) payable {
        Stock stock = stocks[stockId];
        require ( msg.value >= amount * stock.price);
        uint256 totalSpent = 0;
        uint256 amount = _amount;
        for (uint256 i = 0; i < 100; i++) {
            uint256 recordId = stock.lastSelledRecordId;
            if (amount <= 0 || recordId == 0) {
                break;
            }
            if (amount < records[recordId].remain) {
                records[recordId].remain -= amount;
                stock.totalRemain -= amount;
                balances[records[recordId].supplyer] += stock.price * amount;
                totalSpent += stock.price * amount;
                amount = 0;
            }  else { // next record 
                amount -= records[recordId].remain;
                stock.totalRemain -= records[recordId].remain;
                balances[records[recordId].supplyer] += stock.price * records[recordId].remain;
                totalSpent += stock.price * records[recordId].remain;
                records[recordId].remain = 0;
                stock.lastSelledRecordId = records[recordId].nextRecordId;
            }
        }
        if (recordId == 0) {
            StockShortage(stockId, amount);
        }

        if (amount != _amount) {
            Selled(stockId, _amount - amount, stock.totalRemain);
        }
    }

    function deposit (uint256 amount) {
        require (balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        msg.sender.transfer(amount);
    }
 }