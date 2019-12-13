pragma solidity ^0.4.24;

contract test {
    struct receipt {
        uint rid;
        address Debtor;  
        address Creditor;
        uint amount;
        bool confirmed;  //confirmed by the debtor
        bool evaluated;  //evaluated by the bank
        uint deadline;
        bool violated;  //true when the receipt is unpaid after the deadline
    }
    
    struct companyInfo {
        string companyName;
        string companyAddress;
        string description;
    }
    
    receipt[] public receipts;
    address[] public companies;  //registered companies' list
    mapping (address => uint) balances;  //balances can't be public, function checkBalance allows company to check its own balance
    mapping (address => uint) public credits;  //credits are open to the public
    mapping (address => companyInfo) public Infos;
    
    constructor() {
        companies.push(0x43c4d4fe096740dfa1c7ebd186246dc785e238d3);  //addr of company A
        companies.push(0xc75698618c5f890f699d92a4eecb750cc7abf951);  //addr of company B
        companies.push(0xe18b3352f2cd1cf73caacadc742904e5e9bea3a3);  //addr of company C
    }
    
    function register() public returns (bool) {  //register a company
        uint i;
        for (i = 0; i < companies.length; i++) {
            if (msg.sender == companies[i]) {
                return false;  //already registered
            }
        }
        companies.push(msg.sender);
        return true;
    }

    function uodateBalance(address receiver, uint amount_, bool add) public returns (bool) {
        //can only call by the bank
        //add balance to a company
        require(msg.sender == 0xb820b9f01be068e273ac75e530f1f55c70cc648d);
        if (add == true) {
            balances[receiver] += amount_;
            credits[receiver] += amount_;  //if one owns more money, he has more credit
            return true;
        }
        else if (balances[receiver] >= amount_ && credits[receiver] >= amount_) {
            balances[receiver] -= amount_;
            credits[receiver] -= amount_; 
            return true;  
        } 
        return false;
    }

    function updateCredit(address receiver, uint amount_, bool add) public returns (bool) {
        //can only call by the bank
        //add credit to a company
        require(msg.sender == 0xb820b9f01be068e273ac75e530f1f55c70cc648d);
        if (add == true) {
            credits[receiver] += amount_;
            return true;
        }
        else if (credits[receiver] >= amount_) {
            credits[receiver] -= amount_; 
            return true;  
        } 
        return false;
    }

    function checkBalance(address company) public returns (uint) {
        require(company == msg.sender);
        //call by any company, check its balance
        return balances[company];
    }

    function makeReceipt(uint rid_, address receiver, uint amount_, bool evaluated_, uint time) public returns (bool) {
        //call by the creditor
        //declare a receipt(the receiver owes me money)
        receipts.push(receipt({
            rid: rid_,
            Debtor: receiver,
            Creditor: msg.sender,
            amount: amount_,
            confirmed: false,
            evaluated: evaluated_,  //if true, means that the creditor require debtor's credit guaranty
            deadline: now + time,  //time indicates how many time left
            violated: false
        }));
        return true;
    }
    
    function checkReceiptDebtor(address company) public returns (uint[]) {
        require(company == msg.sender);
        //call by any company
        //check receipts on which he is the debtor
        uint[] ret;
        uint i;
        for (i = 0; i < receipts.length; i++) {
            if (company == receipts[i].Debtor && receipts[i].amount != 0) {
                ret.push(i);
            }
        }
        return ret;
    }

    function checkReceiptCreditor(address company) public returns (uint[]) {
        require(company == msg.sender);
        //call by any company
        //check receipts on which he is the creditor
        uint[] ret;
        uint i;
        for (i = 0; i < receipts.length; i++) {
            if (company == receipts[i].Creditor && receipts[i].amount != 0) {
                ret.push(i);
            }
        }
        return ret;
    }

    function confirmReceipt(uint rid_, address sender_, uint amount_, bool evaluated_) public returns (bool) {
        //call by the debtor
        //confirm a receipt(I do owe the sender that amount of money)
        uint i;
        for (i = 0; i < receipts.length; i++) {
            if (receipts[i].Debtor == msg.sender && receipts[i].rid == rid_ && receipts[i].amount == amount_ 
            && receipts[i].Creditor == sender_ && receipts[i].evaluated == evaluated_) {
                //deadline is related to the function call, cannot be specified accuratedly
                if (receipts[i].evaluated == false) {  //don't need credit guaranty
                    receipts[i].confirmed = true;
                    return true;
                }
                //if credit guaranty is needed, the debtor can't confirm it unless it has enough credit 
                else if (credits[receipts[i].Debtor] >= receipts[i].amount) {
                    //the debtor's credit pass to the creditor with specified amount
                    credits[receipts[i].Debtor] -= receipts[i].amount;
                    credits[receipts[i].Creditor] += receipts[i].amount;   
                    receipts[i].confirmed = true;  
                    return true; 
                }
            }
        }
        return false;
    }

    function evaluateReceipt(uint rid_, address debtor_) public returns (bool) { 
        uint i;
        //the bank believes that this debtor is able to pay this receipt
        for (i = 0; i < receipts.length; i++) {
            if (receipts[i].Debtor == debtor_ && receipts[i].rid == rid_ && receipts[i].evaluated == false  
            && credits[receipts[i].Debtor] >= receipts[i].amount) {
                //the debtor's credit pass to the creditor with specified amount
                credits[receipts[i].Debtor] -= receipts[i].amount;
                credits[receipts[i].Creditor] += receipts[i].amount;
                receipts[i].evaluated = true;
                return true;
            }
        }
        return false;
    }
    
    function transferReceipt(uint rid_, uint newrid, uint newamount, address newcreditor) public returns (bool) {
        //call by company who owns a confirmed receipt and owes money to another company
        uint i;
        for (i = 0; i < receipts.length; i++) {
            //verify the ownership
            if (receipts[i].rid == rid_ && receipts[i].Creditor == msg.sender && receipts[i].confirmed == true) { 
                //the receipt's owner wants to transfer part of it to a newcreditor
                if (receipts[i].amount < newamount)
                    return false;  // can't afford
                else {
                    receipts[i].amount -= newamount;

                    receipts.push(receipt({
                    rid: newrid,
                    Debtor: receipts[i].Debtor,
                    Creditor: newcreditor,
                    amount: newamount,
                    confirmed: true,  //has already paid(-amount), have to confirm here
                    evaluated: receipts[i].evaluated,
                    deadline: receipts[i].deadline,
                    violated: false
                }));
                if(receipts[i].evaluated == true) {
                    credits[receipts[i].Creditor] -= newamount;
                    credits[newcreditor] += newamount;
                }
                    return true;
                }
            }
        }
        return false;  //can't find such receipt   
    }
    
    function loan(uint amount) public returns (bool) {
        uint i;
        if (credits[msg.sender] >= amount) {
            credits[msg.sender] -= amount;
            balances[msg.sender] += amount;
            return true;
        }
        return false;
    }
    
    function repay(uint rid_, address creditor_, uint amount_) public returns (bool) {
        //call by the debtor
        //payback a receipt
        uint i;
        for (i = 0; i < receipts.length; i++) {
            if (receipts[i].Debtor == msg.sender && receipts[i].rid == rid_ && 
            receipts[i].Creditor == creditor_ && receipts[i].amount == amount_) {
                if (balances[msg.sender] < amount_)
                    return false;  //can't afford
                else {
                    receipts[i].amount = 0;
                    balances[msg.sender] -= amount_;
                    balances[receipts[i].Creditor] += amount_;
                    if (receipts[i].evaluated == false) {
                        credits[msg.sender] -= amount_;  //haven't paid its credit, credit reduced here with the decrease of balance
                        credits[receipts[i].Creditor] += amount_;
                    }
                        
                    return true;
                }
            }
        } 
    }

    function autoRepays() public returns (bool) {
        //can only call by the bank
        //check whether the companies have expired receipts to pay
        //If they have, try auto repay
        //If they don't have the money, note that they violated the contracts and reduce their credits
        require(msg.sender == 0xb820b9f01be068e273ac75e530f1f55c70cc648d);   
        uint i;
        for (i = 0; i < receipts.length; i++) {
            if (now > receipts[i].deadline && receipts[i].amount != 0) {  //time is up but not repaid 
                if (balances[receipts[i].Debtor] >= receipts[i].amount) {
                    receipts[i].amount = 0;
                    balances[msg.sender] -= receipts[i].amount; 
                    balances[receipts[i].Creditor] += receipts[i].amount;
                    if (receipts[i].evaluated == false) {
                        credits[msg.sender] -= receipts[i].amount;  //haven't paid its credit, credit reduced here with the decrease of balance
                        credits[receipts[i].Creditor] += receipts[i].amount;  
                    }
                         
                }
                else if (receipts[i].violated == false) {  //time is up but not repaid and can't afford
                    receipts[i].violated = true;
                    credits[receipts[i].Debtor] -= 3 * receipts[i].amount;  //punishment for violating the receipt
                }
            }
        }
        return true;
    }
    
    function setCompanyName(address addr, string name) public returns (bool) {
        //call by any company, set its info
        require(addr == msg.sender);
        Infos[msg.sender].companyName = name;
        return true;
    }
    
    function setCompanyAdress(address addr, string Caddr) public returns (bool) {
        //call by any company, set its info
        require(addr == msg.sender);
        Infos[msg.sender].companyAddress = Caddr;
        return true;
    }
    
    function setDescription(address addr, string description_) public returns (bool) {
        //call by any company, set its info
        require(addr == msg.sender);
        Infos[msg.sender].description = description_;
        return true;
    }
    
}
    
    
