// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiSig {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txID);
    event Approve(address indexed admin, uint indexed txID);
    event Revoke(address indexed admin, uint indexed txID);
    event Execute(uint indexed txID);

    struct Transaction {
        address to;       
        uint value;
        bytes data;
        bool executed;
    }

    //address gNairaContractAddress;

    address[] public admins;
    mapping(address => bool) public isAdmin;
    uint public required;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    //this modifier checks is caller is a multiSig admin
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "sender is not an admin");
        _;
    }

    //this modifier checks if a proposal exists
    modifier txExists(uint _txID) {
        require(_txID < transactions.length, "proposal does not exist");
        _;
    } 

    //this modifier checks that a proposal is not approved yet
    modifier notApproved(uint _txID) {
        require(!approved[_txID][msg.sender], "proposal already approved");
        _;
    }

    //this modifier checks if a mint/burn proposal has not been executed
    modifier notExecuted(uint _txID) {
        require(!transactions[_txID].executed, "proposal already executed");
        _;
    }

    //this modifier ensures caller is gNairaContract
    // modifier onlygNairaContract() {
    //     require(msg.sender == gNairaContractAddress);
    //     _;
    // }

    /* upon deployment, an array of admins must be initialized and the required amount of
    signatures for proposals must be initailized. */
    constructor(address[] memory _admins, uint _required) {
        //checks that deployer set one or more addresses as admin
        require(_admins.length > 0, "at least one admin required");
        //checks that required set by admin is greater than one and less or equal to the number of admins
        require(_required > 0 && _required <= _admins.length, "invalid required");

        /*this loops through the admin array inputed by deployer and updates the local 'admin' 
        array with all address and also updates the isAdmin mapping for each admin*/
        for (uint i = 0; i < _admins.length; i++) {
            require(_admins[i] != address(0), "invalid adrress");
            require(!isAdmin[_admins[i]], "admin already exists");
            admins.push(_admins[i]);
            isAdmin[_admins[i]] = true;
        }

        required = _required;
    
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /*this method can only be called by the gNairaContract when the governor wants to mint or burn.
    this method is used to submit a mint or burn proposal for approval by multiSig admins*/
    function submit(address _to, uint _value, bytes calldata _data) external onlyAdmin {
        Transaction memory newTransaction = Transaction(_to, _value, _data, false);
        transactions.push(newTransaction);
        
        emit Submit(transactions.length - 1);
    }

    /*this function is called by admins to approve proposals
    */
    function adminTxApprove(uint _txID) 
    external onlyAdmin txExists(_txID) notApproved(_txID) notExecuted(_txID) {
        approved[_txID][msg.sender] = true;
        emit Approve(msg.sender, _txID);
    }

    //returns the approval count per proposal
    function getApprovalCount(uint _txID) private view returns (uint count) {
        //this loops through all admins in the 'admin array' and checks for approval for a proposal 
        for (uint i; i < admins.length; i++) {
            if(approved[_txID][msg.sender]) {
                count += 1;
            }
        }

    }

    /*this function is called when a proposal is to be executed. the proposal must have
    the minimum amount of required approvals to be executed*/
    function execute(uint _txID) external txExists(_txID) notExecuted(_txID) {  //isGovernor?
        require(getApprovalCount(_txID) >= required, "not enough approvals");
        Transaction storage transaction = transactions[_txID];
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "transaction failed");
        
        emit Execute(_txID);
    }

    // this function is used to revoke approval for a proposal by an admin
    function revoke(uint _txID) external onlyAdmin txExists(_txID) notExecuted(_txID) {
        require(approved[_txID][msg.sender], "transaction not approved");
        approved[_txID][msg.sender] = false;
        emit Revoke(msg.sender, _txID);
    } 
}