// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable{
    
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    mapping(address => Voter) listVoters; // Whitelisted voters who can partitipate to the vote
    address[] listAddressVoters; //Keep address voters in an array in order to be able to delete the mapping later
    Proposal[] listProposals; //List of all propasals sent by voters - only visible by voters
    Proposal public winningProposal; // Object of winning proposal - visible by everyone
    uint public winningProposalId; // Identifier of winner proposal - visible by everyone
    WorkflowStatus votingStatus; // Current voting status - only visible by admin

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    modifier onlyVoters() {
        require(listVoters[msg.sender].isRegistered == true, "You are not a voter");
        _;
    }

    function resetVote() public onlyOwner{
        require(votingStatus == WorkflowStatus.VotesTallied, "Even if you are admin, you can reset the vote only at the end");
        
        for(uint i=0;i<listAddressVoters.length;i++){
            delete listVoters[listAddressVoters[i]];
        }
        delete listAddressVoters;
        delete listProposals;
        delete winningProposalId;
        delete winningProposal;
        delete votingStatus;
    }

    function registerVoter(address _addrVoter) public onlyOwner{
        require(votingStatus == WorkflowStatus.RegisteringVoters, "We are not in step : RegisteringVoters");
        require(listVoters[_addrVoter].isRegistered == false, "This voter is already registered");

        //Update voter structure for this _addrVoter
        listVoters[_addrVoter] = Voter(true, false, 0);
        //Keep address in an array to iterate on later
        listAddressVoters.push(_addrVoter);

        emit VoterRegistered(_addrVoter);
    }

    function changeStep(WorkflowStatus _newStatus) public onlyOwner{
        require(uint(_newStatus) == uint(votingStatus)+1, "Status forbiden");

        emit WorkflowStatusChange(votingStatus, _newStatus);

        votingStatus = _newStatus;

        //If we are at the end of the vote, compute automaticaly which proposal win
        if(votingStatus == WorkflowStatus.VotesTallied){
            _setWinningProposal();
        }
    }

    function addProposal(string calldata _description) public onlyVoters{
        require(votingStatus == WorkflowStatus.ProposalsRegistrationStarted, "We are not in step : ProposalsRegistrationStarted");

        listProposals.push(Proposal(_description, 0));
        
        emit ProposalRegistered(listProposals.length-1);
    }

    function vote(uint _proposalId) public onlyVoters{
        require(votingStatus == WorkflowStatus.VotingSessionStarted, "We are not in step : VotingSessionStarted");
        require(listVoters[msg.sender].hasVoted == false, "You have already voted");
        require(_proposalId < listProposals.length, "Proposal ID unkwown");

        listProposals[_proposalId].voteCount++;

        listVoters[msg.sender].votedProposalId = _proposalId;
        listVoters[msg.sender].hasVoted = true;

        emit Voted(msg.sender, _proposalId);
    }

    function _setWinningProposal() internal {
        winningProposalId = _findWinningProposalId();
        winningProposal = listProposals[winningProposalId];
    }

    function _findWinningProposalId() internal view returns (uint){
        uint maxVoters;
        uint winningProposalIdTemp;

        for(uint i=0;i<listProposals.length;i++){
            if(listProposals[i].voteCount > maxVoters){
                maxVoters = listProposals[i].voteCount;
                winningProposalIdTemp = i;
            }
        }

        return winningProposalIdTemp;
    }

    /*
    * Get list of all proposals
    * Available only for voters 
    */
    function getListProposals() public view onlyVoters returns (Proposal[] memory) {
        return listProposals;
    }
	
	/*
    * Get a vote by address
    * Available only for voters 
    */
	function getVoteByAddress(address _addr) public view onlyVoters returns (uint ) {
        return listVoters[_addr].votedProposalId;
    }

    /*
    * Get current voting status
    * Available only for admin
    */
    function getVotingStatus() public view onlyOwner returns (WorkflowStatus){
        return votingStatus;
    }
}