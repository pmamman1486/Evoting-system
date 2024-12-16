import { describe, it, beforeEach, expect } from 'vitest';

// Mock state and functions for the contract logic
// 


let proposals: Record<number, any>;
let votes: Record<string, any>;
let tokenOwner: string;
let nextProposalId: number;
let minProposalDuration: number;

const ERR_PROPOSAL_NOT_FOUND = 'err u100';
const ERR_VOTING_CLOSED = 'err u101';
const ERR_ALREADY_VOTED = 'err u102';
const ERR_INSUFFICIENT_STAKE = 'err u103';
const ERR_UNAUTHORIZED = 'err u105';

// Mock function to initialize state before each test
beforeEach(() => {
  proposals = {};
  votes = {};
  tokenOwner = 'initial_owner';
  nextProposalId = 1;
  minProposalDuration = 1440; // 1 day

  // Reset the block height (assuming each test simulates fresh blocks)
  (globalThis as any).blockHeight = 1000;
});

// Mock contract functions

const createProposal = (description: string, deadline: number, rewardAmount: number) => {
  if (deadline < (globalThis as any).blockHeight + minProposalDuration) {
    throw new Error('ERR_INVALID_DEADLINE');
  }

  const proposalId = nextProposalId++;
  proposals[proposalId] = {
    creator: tokenOwner,
    description,
    deadline,
    totalVotes: 0,
    forVotes: 0,
    againstVotes: 0,
    status: 'active',
    rewardPool: rewardAmount,
  };
  return proposalId;
};
const voteOnProposal = (proposalId: number, amount: number, voteFor: boolean) => {
  const proposal = proposals[proposalId];
  if (!proposal) throw new Error(ERR_PROPOSAL_NOT_FOUND);
  if ((globalThis as any).blockHeight > proposal.deadline) throw new Error(ERR_VOTING_CLOSED);
  if (votes[`${proposalId}:${tokenOwner}`]) throw new Error(ERR_ALREADY_VOTED);

  // Record the vote
  votes[`${proposalId}:${tokenOwner}`] = { weight: amount, vote: voteFor };

  // Update proposal totals
  proposal.totalVotes += amount;
  if (voteFor) {
    proposal.forVotes += amount;
  } else {
    proposal.againstVotes += amount;
  }
};

const finalizeVote = (proposalId: number) => {
  const proposal = proposals[proposalId];
  if (!proposal) throw new Error(ERR_PROPOSAL_NOT_FOUND);
  if ((globalThis as any).blockHeight <= proposal.deadline) throw new Error(ERR_VOTING_CLOSED);

  proposal.status = proposal.forVotes > proposal.againstVotes ? 'passed' : 'rejected';
};

const getProposal = (proposalId: number) => proposals[proposalId] || null;

const claimReward = (proposalId: number) => {
  const proposal = proposals[proposalId];
  const userVote = votes[`${proposalId}:${tokenOwner}`];
  if (!proposal || !userVote) throw new Error(ERR_UNAUTHORIZED);
  if (proposal.status === 'active') throw new Error('ERR_PROPOSAL_NOT_FINALIZED');
  const reward = Math.floor((userVote.weight * proposal.rewardPool) / proposal.totalVotes);
  return reward;
};

// Test Suite

describe('Proposal Contract', () => {
  it('should create a proposal successfully', () => {
    const proposalId = createProposal('Test Proposal', (globalThis as any).blockHeight + 2000, 1000);
    expect(proposalId).toEqual(1);
    const proposal = getProposal(proposalId);
    expect(proposal).toMatchObject({
      creator: tokenOwner,
      description: 'Test Proposal',
      status: 'active',
      rewardPool: 1000,
    });
  });

  it('should reject proposal with invalid deadline', () => {
    expect(() =>
      createProposal('Invalid Proposal', (globalThis as any).blockHeight + 100, 500)
    ).toThrow('ERR_INVALID_DEADLINE');
  });

  it('should allow voting on an active proposal', () => {
    const proposalId = createProposal('Voting Proposal', (globalThis as any).blockHeight + 2000, 1000);
    voteOnProposal(proposalId, 100, true);
    const proposal = getProposal(proposalId);
    expect(proposal.forVotes).toEqual(100);
  });

  it('should reject duplicate votes', () => {
    const proposalId = createProposal('Duplicate Vote Proposal', (globalThis as any).blockHeight + 2000, 1000);
    voteOnProposal(proposalId, 100, true);
    expect(() => voteOnProposal(proposalId, 50, false)).toThrow(ERR_ALREADY_VOTED);
  });


  it('should not finalize an active proposal', () => {
    const proposalId = createProposal('Active Proposal', (globalThis as any).blockHeight + 2000, 500);
    expect(() => finalizeVote(proposalId)).toThrow(ERR_VOTING_CLOSED);
  });


  it('should reject reward claim if the proposal is not finalized', () => {
    const proposalId = createProposal('Unfinalized Proposal', (globalThis as any).blockHeight + 2000, 1000);
    voteOnProposal(proposalId, 100, true);
    expect(() => claimReward(proposalId)).toThrow('ERR_PROPOSAL_NOT_FINALIZED');
  });
});



let blockHeight = 1000; // Simulated block height for tests
 minProposalDuration = 1440; // Minimum proposal duration

const proposalsIniatiate = (description: string, deadline: number, rewardAmount: number) => {
  if (deadline < blockHeight + minProposalDuration) {
    throw new Error('ERR_INVALID_DEADLINE');
  }
  // Proceed with proposal creation logic
  return { id: 1, description, deadline, rewardAmount };
};

describe('Proposal Contract', () => {
  beforeEach(() => {
    blockHeight += 1; // Simulate block advancing
  });

  it('should create a valid proposal', () => {
    const validDeadline = blockHeight + minProposalDuration; // Ensure the deadline is valid
    const proposal = proposalsIniatiate('Test Proposal', validDeadline, 100);
    expect(proposal).toMatchObject({ id: 1, description: 'Test Proposal' });
  });

  it('should throw ERR_INVALID_DEADLINE for early deadline', () => {
    const invalidDeadline = blockHeight + minProposalDuration - 1; // Invalid deadline
    expect(() =>
      proposalsIniatiate('Invalid Proposal', invalidDeadline, 100)
    ).toThrow('ERR_INVALID_DEADLINE');
  });
});
