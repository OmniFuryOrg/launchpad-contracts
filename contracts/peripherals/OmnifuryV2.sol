// SPDX-License-Identifier: MIT
//website: https://omnifury.org/
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ArbSys {
    function arbBlockNumber() external view returns (uint256);
    function arbBlockHash(uint256 blockNumber) external view returns (bytes32);
}

contract OmnifuryV2 is ReentrancyGuard, Ownable {
    using Address for address payable;

    bool public paused;
    uint256 public mintFee;
    uint256 public depositIndex;
    uint256 public initialTimestamp;
    uint256 public secondCntPerRound = 120;
    uint256 public cleaningSeconds = 12;
    uint256 constant public ARBITRUM_CHAIN_ID = 42161;
    uint256 constant public ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    ArbSys constant public arbSys = ArbSys(address(100));

    mapping (uint256 => mapping (address => bool)) public roundAddrToFlag;
    mapping (address => uint256) public addrToTotalDeposit;

    event Paused(address account);
    event Unpaused(address account);
    event DepositEvent(uint256 depositIndex, uint256 ts, uint256 roundId, address trader, uint256 amount);

    modifier whenNotPaused() {
        require(paused == false, "paused");
        _;
    }

    constructor() {
      mintFee = 0.3 ether;
      initialTimestamp = block.timestamp;
    }

    function setMintFee(uint256 amount) external onlyOwner {
        mintFee = amount;
    }

    function setInitialTimestamp(uint256 timestamp) external onlyOwner {
        initialTimestamp = timestamp;
    }

    function setSecondCntPerRound(uint256 secondCnt) external onlyOwner {
        secondCntPerRound = secondCnt;
    }

    function setCleaningSeconds(uint256 val) external onlyOwner {
        cleaningSeconds = val;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function currentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    //included
    function getBeginTimestamp(uint256 roundId) public view returns (uint256) {
      return initialTimestamp + secondCntPerRound * roundId;
    }

    //included
    function getEndTimestamp(uint256 roundId) public view returns (uint256) {
      return initialTimestamp + secondCntPerRound * (roundId + 1) - 1;
    }

    function bet(uint256 roundId) external payable nonReentrant whenNotPaused {
        require(msg.value >= mintFee, "Omnifury: fee not enough");
        require(roundAddrToFlag[roundId][msg.sender] == false, "Omnifury: already deposit in this round");

        uint256 curTimestamp = currentTimestamp();
        uint256 beginTimestamp = getBeginTimestamp(roundId);
        uint256 endTimestampOfRound = getEndTimestamp(roundId);
        uint256 endTimestamp = endTimestampOfRound - cleaningSeconds;
        require(beginTimestamp <= endTimestamp, "Omnifury: contract config error!");

        require(beginTimestamp <= curTimestamp, "Omnifury: roundId not open yet, please wait!");
        require(curTimestamp <= endTimestamp, "Omnifury: roundId alrady closed!");

        addrToTotalDeposit[msg.sender] += msg.value;
        roundAddrToFlag[roundId][msg.sender] = true;

        emit DepositEvent(depositIndex++, block.timestamp, roundId, msg.sender, msg.value);
    }

    function withdraw() external nonReentrant onlyOwner {
        payable(msg.sender).sendValue(address(this).balance);
    }

    function balanceOf() external view returns (uint256) {
        return address(this).balance;
    }

    function currentBlockNumber() external view returns (uint256) {
        if (block.chainid == ARBITRUM_CHAIN_ID || block.chainid == ARBITRUM_SEPOLIA_CHAIN_ID) {
            return arbSys.arbBlockNumber();
        }

        return block.number;
    }
}
