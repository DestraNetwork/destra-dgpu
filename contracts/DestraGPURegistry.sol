// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract DestraGPURegistry is Ownable {
    uint256 public depositAmount;
    uint256 public nextDepositAmount;
    uint256 public nextDeregisterPeriod;
    string public headNodeAddress;
    string public pendingHeadNodeAddress;
    bool public headNodeTimelockEnabled;
    uint256 public headNodeChangeTime;
    uint256 public constant HEAD_NODE_TIMELOCK_DURATION = 3 days;
    uint256 public constant DEPOSIT_CHANGE_TIMELOCK_DURATION = 1 days;
    uint256 public constant TIME_LOCK = 1 days;
    uint256 public deregisterPeriod = 90 days;
    uint256 public gpuNodeCounter;
    uint256 public voteThreshold;
    uint256 public nextVoteThreshold;
    uint256 public thresholdChangeTime;
    uint256 public deregisterChangeTime;
    uint256 public depositChangeTime;

    struct GPUNode {
        uint256 registrationTime;
        bool isRegistered;
        uint256 nodeId;
        uint256 positiveVotes;
        uint256 negativeVotes;
    }

    mapping(address => GPUNode[]) public workerGPUNodes;

    event NodeRegistered(address indexed operator, uint256 indexed nodeId);
    event NodeDeregistered(address indexed operator, uint256 indexed nodeId);
    event HeadNodeAddressChanged(string indexed newHeadNodeAddress);
    event DepositAmountChanged(uint256 newDepositAmount);
    event VoteThresholdChanged(uint256 newVoteThreshold);
    event DeregisterPeriodChanged(uint256 newDeregisterPeriod);
    event Blacklisted(uint256 indexed nodeId);

    constructor(uint256 _initialDepositAmount, uint256 _initialVoteThreshold) Ownable(msg.sender) {
        depositAmount = _initialDepositAmount;
        voteThreshold = _initialVoteThreshold;
        gpuNodeCounter = 1; // Start node IDs from 1 for better readability
    }

    function registerGPUNode() external payable {
        require(msg.value == depositAmount, "Incorrect deposit amount");

        workerGPUNodes[msg.sender].push(GPUNode({
            registrationTime: block.timestamp,
            isRegistered: true,
            nodeId: gpuNodeCounter,
            positiveVotes: 0,
            negativeVotes: 0
        }));

        emit NodeRegistered(msg.sender, gpuNodeCounter);
        gpuNodeCounter++;
    }

    function deregisterGPUNode(uint256 _nodeId) external {
        GPUNode[] storage userGPUNodes = workerGPUNodes[msg.sender];
        uint256 index = _findGPUNodeIndex(userGPUNodes, _nodeId);

        require(userGPUNodes[index].isRegistered, "GPUNode not registered");
        require(
            block.timestamp >= userGPUNodes[index].registrationTime + deregisterPeriod,
            "Cannot deregister before the deregister period"
        );

        userGPUNodes[index].isRegistered = false;
        payable(msg.sender).transfer(depositAmount);

        emit NodeDeregistered(msg.sender, _nodeId);
    }

    function requestHeadNodeAddressChange(string memory _newHeadNodeAddress) external onlyOwner {
        pendingHeadNodeAddress = _newHeadNodeAddress;
        headNodeChangeTime = block.timestamp + HEAD_NODE_TIMELOCK_DURATION;
    }

    function confirmHeadNodeAddressChange() external onlyOwner {
        require(
            !headNodeTimelockEnabled || block.timestamp >= headNodeChangeTime,
            "Timelock period not expired"
        );

        headNodeAddress = pendingHeadNodeAddress;
        pendingHeadNodeAddress = "";
        emit HeadNodeAddressChanged(headNodeAddress);
    }

    function setHeadNodeAddressImmediate(string memory _newHeadNodeAddress) external onlyOwner {
        require(!headNodeTimelockEnabled, "Timelock is enabled, use requestHeadNodeAddressChange");

        headNodeAddress = _newHeadNodeAddress;
        emit HeadNodeAddressChanged(_newHeadNodeAddress);
    }

    function enableHeadNodeTimelock() external onlyOwner {
        headNodeTimelockEnabled = true;
    }

    function votePeer(address _peerAddress, uint256 _nodeId, bool positive) external {
        require(isGPUNodeRegistered(msg.sender), "Only registered nodes can vote");

        GPUNode[] storage peerGPUNodes = workerGPUNodes[_peerAddress];
        uint256 index = _findGPUNodeIndex(peerGPUNodes, _nodeId);

        if (positive) {
            peerGPUNodes[index].positiveVotes++;
        } else {
            peerGPUNodes[index].negativeVotes++;
        }
    }

    function blacklistPeer(address _peerAddress, uint256 _nodeId) external onlyOwner {
        GPUNode[] storage peerGPUNodes = workerGPUNodes[_peerAddress];
        uint256 index = _findGPUNodeIndex(peerGPUNodes, _nodeId);

        uint256 totalVotes = peerGPUNodes[index].positiveVotes + peerGPUNodes[index].negativeVotes;
        require(totalVotes >= voteThreshold, "Not enough votes in total");

        uint256 percentNegative = (peerGPUNodes[index].negativeVotes * 100) / totalVotes;
        require(percentNegative > 50, "Less than 50% negative votes");

        delete peerGPUNodes[index];
        emit Blacklisted(_nodeId);
    }

    function changeVoteThreshold(uint256 _newThreshold) external onlyOwner {
        require(block.timestamp >= thresholdChangeTime, "Time lock not expired");
        nextVoteThreshold = _newThreshold;
        thresholdChangeTime = block.timestamp + TIME_LOCK;
    }

    function confirmThresholdChange() external onlyOwner {
        require(block.timestamp >= thresholdChangeTime, "Time lock not expired");
        require(nextVoteThreshold != 0, "No threshold change pending");

        voteThreshold = nextVoteThreshold;
        nextVoteThreshold = 0;
        emit VoteThresholdChanged(voteThreshold);
    }

    function setNextDepositAmount(uint256 _newDepositAmount) external onlyOwner {
        nextDepositAmount = _newDepositAmount;
        depositChangeTime = block.timestamp + TIME_LOCK;
    }

    function confirmDepositChange() external onlyOwner {
        require(block.timestamp >= depositChangeTime, "Time lock not expired");
        require(nextDepositAmount != 0, "No deposit change pending");

        depositAmount = nextDepositAmount;
        nextDepositAmount = 0;
        emit DepositAmountChanged(depositAmount);
    }

    function setNextDeregisterPeriod(uint256 _newDeregisterPeriod) external onlyOwner {
        nextDeregisterPeriod = _newDeregisterPeriod;
        deregisterChangeTime = block.timestamp + TIME_LOCK;
    }

    function confirmDeregisterPeriodChange() external onlyOwner {
        require(block.timestamp >= deregisterChangeTime, "Time lock not expired");
        require(nextDeregisterPeriod != 0, "No deregister period change pending");

        deregisterPeriod = nextDeregisterPeriod;
        nextDeregisterPeriod = 0;
        emit DeregisterPeriodChanged(deregisterPeriod);
    }

    function verifyGPUNode(address _nodeOperator, uint256 _nodeId) external view returns (bool, uint256) {
        GPUNode[] memory userGPUNodes = workerGPUNodes[_nodeOperator];
        uint256 index = _findGPUNodeIndex(userGPUNodes, _nodeId);
        GPUNode memory node = userGPUNodes[index];
        return (node.isRegistered, node.registrationTime);
    }

    function isGPUNodeRegistered(address _nodeOperator) internal view returns (bool) {
        GPUNode[] memory userGPUNodes = workerGPUNodes[_nodeOperator];
        for (uint256 i = 0; i < userGPUNodes.length; i++) {
            if (userGPUNodes[i].isRegistered) {
                return true;
            }
        }
        return false;
    }

    function _findGPUNodeIndex(GPUNode[] memory userGPUNodes, uint256 _nodeId) internal pure returns (uint256) {
        for (uint256 i = 0; i < userGPUNodes.length; i++) {
            if (userGPUNodes[i].nodeId == _nodeId) {
                return i;
            }
        }
        revert("Node ID not found");
    }

    // Fallback function to accept ETH
    receive() external payable {}

    // Function to withdraw contract balance (onlyOwner)
    function withdrawBalance() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}