// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;
import "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract GasContract is Ownable {
    using MerkleProof for bytes32[];

    bytes32 merkleRoot1;
    bytes32 merkleRoot2;
    bytes32 merkleRoot3;

    uint256 public totalSupply; // cannot be updated
    uint256 paymentCounter;
    uint256 tradePercent = 12;
    address contractOwner;
    address[5] public administrators;
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }
    PaymentType constant defaultPayment = PaymentType.Unknown;

    mapping(address => uint256) public balances;
    mapping(address => Payment[]) payments;
    History[] public paymentHistory; // when a payment was updated

    struct Payment {
        uint256 paymentID;
        bool adminUpdated;
        PaymentType paymentType;
        address recipient;
        string recipientName; // max 8 characters
        address admin; // administrators address
        uint256 amount;
    }

    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdmin() {
        require(checkForAdmin(msg.sender), "Gas Contract -  Caller not admin");
        _;
    }

    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        totalSupply = _totalSupply;

        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (_admins[ii] != address(0)) {
                administrators[ii] = _admins[ii];
                if (_admins[ii] == msg.sender) {
                    balances[msg.sender] = totalSupply;
                } else {
                    balances[_admins[ii]] = 0;
                }
            }
        }
    }

    function checkForAdmin(address _user) public view returns (bool admin) {
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin = true;
                break;
            }
        }
        return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        uint256 balance = balances[_user];
        return balance;
    }

    function getTradingMode() public view returns (bool mode_) {
        return true;
    }

    function addHistory(address _updateAddress, bool _tradeMode)
        public
        returns (bool status_, bool tradeMode_)
    {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
        bool[] memory status = new bool[](tradePercent);
        for (uint256 i = 0; i < tradePercent; i++) {
            status[i] = true;
        }
        return ((status[0] == true), _tradeMode);
    }

    function getPayments(address _user)
        public
        view
        returns (Payment[] memory payments_)
    {
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public returns (bool status_) {
        require(
            balances[msg.sender] >= _amount,
            "Sender has insufficient Balance"
        );
        require(
            bytes(_name).length < 9,
            "The recipient name is too long, there is a max length of 8 characters"
        );
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        Payment memory payment;
        payment.admin = address(0);
        payment.adminUpdated = false;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = _name;
        payment.paymentID = ++paymentCounter;
        payments[msg.sender].push(payment);
        bool[] memory status = new bool[](tradePercent);
        for (uint256 i = 0; i < tradePercent; i++) {
            status[i] = true;
        }
        return (status[0] == true);
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdmin {
        require(
            _ID > 0,
            "Gas Contract - Update Payment function - ID must be greater than 0"
        );
        require(
            _amount > 0,
            "Gas Contract - Update Payment function - Amount must be greater than 0"
        );
        require(
            _user != address(0),
            "Gas Contract - Update Payment function - Administrator must have a valid non zero address"
        );

        for (uint256 ii = 0; ii < payments[_user].length; ii++) {
            if (payments[_user][ii].paymentID == _ID) {
                payments[_user][ii].adminUpdated = true;
                payments[_user][ii].admin = _user;
                payments[_user][ii].paymentType = _type;
                payments[_user][ii].amount = _amount;
                bool tradingMode = getTradingMode();
                addHistory(_user, tradingMode);
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    payments[_user][ii].recipientName
                );
            }
        }
    }

    function addToWhitelist(bytes32 _root, uint256 _tier) external onlyAdmin {
        if (_tier == 1) {
            merkleRoot1 = _root;
        } else if (_tier == 2) {
            merkleRoot2 = _root;
        } else if (_tier == 3) {
            merkleRoot3 = _root;
        }
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        bytes32[] memory _proof
    ) public {
        require(balances[msg.sender] >= _amount, "insufficient Balance");
        require(_amount > 3, " amount to send have to be bigger than 3");
        uint256 tierPrice;
        if (checkIfWhitelisted(_proof, merkleRoot1)) {
            tierPrice = 1;
        } else if (checkIfWhitelisted(_proof, merkleRoot2)) {
            tierPrice = 2;
        } else if (checkIfWhitelisted(_proof, merkleRoot3)) {
            tierPrice = 3;
        } else {
            revert("user not whitelisted/invalid proof");
        }
        balances[msg.sender] -= _amount - tierPrice;
        balances[_recipient] += _amount - tierPrice;
    }

    function checkIfWhitelisted(bytes32[] memory proof, bytes32 root)
        public
        view
        returns (bool isWhiteListed)
    {
        return proof.verify(root, keccak256(abi.encodePacked(msg.sender)));
    }
}