import { describe, it, beforeEach, expect } from 'vitest';

// Mock state and functions for the Clarity contract logic

let proposals: Record<number, any>;
let votes: Record<string, any>;
let tokenOwner: string;
let nextProposalId: number;
let minProposalDuration: number;

const ERR_PROPOSAL_NOT_FOUND = 'err u100';
const ERR_VOTING_CLOSED = 'err u101';
const ERR_ALREADY_VOTED = 'err u102';
const ERR_INSUFFICIENT_STAKE = 'err u103';
const ERR_INVALID_DEADLINE = 'err u104';
const ERR_UNAUTHORIZED = 'err u105';
const ERR_PROPOSAL_ACTIVE = 'err u106';
const ERR_PROPOSAL_NOT_FINALIZED = 'err u107';
const ERR_TRANSFER_FAILED = 'err u108';

beforeEach(() => {
  proposals = {};
  votes = {};
  tokenOwner = 'initial_owner';
  nextProposalId = 1;
  minProposalDuration = 1440; // 1 day
  (globalThis as any).blockHeight = 1000;
});

// Mock functions for contract operations
const createProposal = (description: string, deadline: number, rewardPool: number) => {
  if (deadline < (globalThis as any).blockHeight + minProposalDuration) {
    throw new Error(ERR_INVALID_DEADLINE);
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
    rewardPool,
  };
  return proposalId;
};

const voteOnProposal = (proposalId: number, voter: string, weight: number, voteFor: boolean) => {
  const proposal = proposals[proposalId];
  if (!proposal) throw new Error(ERR_PROPOSAL_NOT_FOUND);
  if ((globalThis as any).blockHeight > proposal.deadline) throw new Error(ERR_VOTING_CLOSED);
  if (votes[`${proposalId}:${voter}`]) throw new Error(ERR_ALREADY_VOTED);

  votes[`${proposalId}:${voter}`] = { weight, vote: voteFor };
  proposal.totalVotes += weight;
  if (voteFor) {
    proposal.forVotes += weight;
  } else {
    proposal.againstVotes += weight;
  }
};

const finalizeProposal = (proposalId: number) => {
  const proposal = proposals[proposalId];
  if (!proposal) throw new Error(ERR_PROPOSAL_NOT_FOUND);
  if ((globalThis as any).blockHeight <= proposal.deadline) throw new Error(ERR_PROPOSAL_ACTIVE);

  proposal.status = proposal.forVotes > proposal.againstVotes ? 'passed' : 'rejected';
};

const claimReward = (proposalId: number, voter: string) => {
  const proposal = proposals[proposalId];
  const voterData = votes[`${proposalId}:${voter}`];
  if (!proposal || !voterData) throw new Error(ERR_UNAUTHORIZED);
  if (proposal.status === 'active') throw new Error(ERR_PROPOSAL_NOT_FINALIZED);

  const reward = Math.floor((voterData.weight * proposal.rewardPool) / proposal.totalVotes);
  return reward;
};

// Tests

describe('Clarity Contract Tests', () => {
  it('should create a proposal successfully', () => {
    const proposalId = createProposal('Test Proposal', (globalThis as any).blockHeight + 2000, 1000);
    expect(proposalId).toBe(1);
    const proposal = proposals[proposalId];
    expect(proposal).toMatchObject({
      creator: tokenOwner,
      description: 'Test Proposal',
      deadline: (globalThis as any).blockHeight + 2000,
      status: 'active',
      rewardPool: 1000,
    });
  });

  it('should reject a proposal with an invalid deadline', () => {
    expect(() => createProposal('Invalid Proposal', (globalThis as any).blockHeight + 100, 500)).toThrow(
      ERR_INVALID_DEADLINE
    );
  });

  it('should allow voting on a proposal', () => {
    const proposalId = createProposal('Voting Proposal', (globalThis as any).blockHeight + 2000, 1000);
    voteOnProposal(proposalId, 'voter1', 50, true);
    const proposal = proposals[proposalId];
    expect(proposal.forVotes).toBe(50);
    expect(proposal.totalVotes).toBe(50);
  });

  it('should reject duplicate votes', () => {
    const proposalId = createProposal('Duplicate Vote Proposal', (globalThis as any).blockHeight + 2000, 1000);
    voteOnProposal(proposalId, 'voter1', 50, true);
    expect(() => voteOnProposal(proposalId, 'voter1', 30, false)).toThrow(ERR_ALREADY_VOTED);
  });

  it('should reject reward claims for active proposals', () => {
    const proposalId = createProposal('Active Proposal', (globalThis as any).blockHeight + 2000, 1000);
    voteOnProposal(proposalId, 'voter1', 50, true);
    expect(() => claimReward(proposalId, 'voter1')).toThrow(ERR_PROPOSAL_NOT_FINALIZED);
  });
});
