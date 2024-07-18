// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSig{
    event Deposit(uint _amount, address _depositor);
    event Withdraw(uint _amount, address _withdrawer);
    // event Propose(address _contract, string _function);
    event Accept(address _signer);
    event Reject(address _signer);
    event AddWallet(address _wallet);
    event KickMember(address _member);
    event Execute(uint _transactionId);
    
    error BadLimit();
    error CopayerLimitReached(uint8 limit);
    error MaxCopayerLimitReached(uint8 max);
    error BadAddress();
    error AlreadySigned();
    error TransactionExecuted(uint8 txnId);
    error TransactionRejected(uint8 txnId);


    struct Transaction{
       uint8 accepts;
       uint8 rejects;
       uint transactionId;
       uint proposalTime;
       address _to;
       bytes _data;
       uint _value;
       mapping(address => bool) signatures;
    }

    // returns 1 if proposed transaction has been executed, -1 if terminated and 0 if pending
    Transaction[] allProposal;
    Transaction[] executed;
    Transaction[] rejected;
    Transaction[] pending;
    mapping(uint8 => bool) executedCheck;
    mapping(uint8 => bool) rejectedCheck;

    
    modifier Onlyonce(uint8 _transactionId){
    if(allProposal[_transactionId - 1].signatures[msg.sender] == true){
        revert AlreadySigned();
    }
    _;
    }
    
    modifier onlyAdmin{
        require(msg.sender == admin, "NotAdmin");
        _;
    }

    modifier onlyMembers{
        require(copayerCheck[msg.sender] == true);
        _;
    }

    enum adjust {INCREASE, REDUCE}

    uint8 maxPendingProposal;
    uint8 copayers;
    uint8 requiredSignatures;
    uint8 constant maxCopayers = 20;
    uint8 activeWallets;
    uint8 kicked;
    uint8 nextTransactionId = 1;
    address admin;
    address[20] copayerAddresses;
    mapping(address => bool) copayerCheck;
    mapping(address => uint) addressTrack;


    constructor(address _admin, uint8 _copayers, uint8 _requiredSignatures){
        if(_copayers > maxCopayers){
            revert BadLimit();
        }
        copayers = _copayers;
        requiredSignatures = _requiredSignatures;
        admin = _admin;
        copayerAddresses[activeWallets] = _admin;
        copayerCheck[_admin] = true;
        addressTrack[_admin] = activeWallets;
        activeWallets += 1;
    }


    // Add new member to the multisig
    function addWallet(address member) external onlyAdmin{
        if(member == address(0)){
            revert BadAddress();
        }
        if (activeWallets == copayers){
            revert CopayerLimitReached(copayers);
        }
        copayerAddresses[activeWallets] = member;
        copayerCheck[member] = true;
        addressTrack[member] = activeWallets;
        activeWallets += 1;
        emit AddWallet(member);
    }

    
    /* adjust the number of copayers 
        
        * Automatically triggered whenever a member is kicked out of the multisig for copayers accuracy

      BEST USE CASES:
        * if Multisig is already full but there's need to add more members (provided hard limit not yet reached)
      
      */

    function adjustCopayerLimit(adjust choice, uint8 newLimit) public onlyAdmin{
        if (choice == adjust.INCREASE){
            require(newLimit > copayers, "");
            if (copayers == maxCopayers){
            revert MaxCopayerLimitReached(maxCopayers);
            }
            if (newLimit > maxCopayers){
            revert BadLimit();
            }
            copayers = newLimit; 
        }

        else{
            require(newLimit == copayers - kicked, "Error");
            copayers = copayers - kicked;
            kicked = 0;
        }
        
    } 

    

    // adjust the required signature amount to execute a proposed transaction
    function adjustRequiredSig(uint8 _newSigLimit) external onlyAdmin{ 
        require(_newSigLimit > 0, "SignersCantBeZero");
        if (_newSigLimit > copayers){
            revert BadLimit();
        }
        requiredSignatures = _newSigLimit;
    }

    // Remove a member from the multisig
    function kickMember(address member) external onlyAdmin{
        activeWallets -= 1;
        kicked += 1;
        delete copayerAddresses[addressTrack[member]];
        delete copayerCheck[member];
        uint start = addressTrack[member];
        for (uint i = 1; i <= (copayers - 1) - addressTrack[member] + 1; i++){
            copayerAddresses[start] = copayerAddresses[start + 1];
            addressTrack[copayerAddresses[start + 1]] = start;
            start += 1;
        }

        adjustCopayerLimit(adjust.REDUCE, copayers - 1);

        emit KickMember(member);
    }


    function getRequiredSig() external view returns(uint8){
        return requiredSignatures;
    }

    function getCopayers() external view returns (uint8){
        return copayers;
    }

    function getCopayerAddresses() external view returns(address[20] memory){
        return copayerAddresses;
    }
    
    function getActiveWallets() external view returns (uint8){
        return activeWallets;
    }
    

    function deposit() external payable{
        emit Deposit(msg.value, msg.sender);
    }


    function proposeTransaction(address _to, uint _value, bytes memory _data) public onlyMembers returns(uint8){
        Transaction storage newTransaction = allProposal.push();
        newTransaction.transactionId = nextTransactionId;
        newTransaction._to = _to;
        newTransaction._data = _data;
        newTransaction._value = _value;
        newTransaction.proposalTime =block.timestamp;
        nextTransactionId ++;
        return (nextTransactionId--);
    }



// Vote for the execution of a proposed transaction

    function acceptProposal(uint8 proposalId) external onlyMembers Onlyonce(proposalId) returns(bool result){
        if(executedCheck[proposalId] == true){
            revert TransactionExecuted(proposalId);
        }

        if(rejectedCheck[proposalId] == true){
            revert TransactionRejected(proposalId);
        }

        allProposal[proposalId - 1].accepts += 1;
        allProposal[proposalId - 1].signatures[msg.sender] = true;
        if (allProposal[proposalId - 1].accepts == requiredSignatures){
            result = execute(proposalId - 1);
            executedCheck[proposalId] = true;
        }

        emit Accept(msg.sender);
    }

// Vote against the execution of a proposed transaction

    function rejectProposal(uint8 proposalId) external onlyMembers Onlyonce(proposalId) returns(string memory result){
            if(executedCheck[proposalId] == true){
                revert TransactionExecuted(proposalId);
            }

            if(rejectedCheck[proposalId] == true){
                revert TransactionRejected(proposalId);
            }

            allProposal[proposalId - 1].rejects += 1;
            allProposal[proposalId - 1].signatures[msg.sender] = true;
            if (allProposal[proposalId - 1].rejects == (copayers - requiredSignatures) + 1){
                result = "rejected";
                rejectedCheck[proposalId] = true;
            }

            emit Reject(msg.sender);
        }


    // Withdraw funds 
    function withdraw(uint amount) external onlyMembers{
        proposeTransaction(msg.sender, amount, "");
    }


  // Execute proposed transaction
    function execute(uint8 _transactionId) internal returns(bool){
        (bool success,) = allProposal[_transactionId]._to.call{value: allProposal[_transactionId]._value}(allProposal[_transactionId]._data);
        return success;
    }

}