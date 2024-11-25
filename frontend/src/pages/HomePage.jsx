import React from 'react';
import Button from '../components/Button';
import { Link } from 'react-router-dom';

const HomePage = () => {
  return (
    <div className="bg-gradient-to-r from-blue-50 via-white to-blue-50 min-h-screen flex flex-col items-center justify-center text-center p-6">
      {/* Header Section */}
      <header className="mb-16">
        <h1 className="text-6xl font-extrabold text-gray-900 leading-tight">
          Welcome to the <span className="text-blue-600">eVoting Platform</span>
        </h1>
        <p className="mt-6 text-lg text-gray-700 max-w-3xl mx-auto">
          A cutting-edge platform empowering communities, DAOs, and organizations to make informed decisions using blockchain technology. Vote, propose, and create a better future together.
        </p>
      </header>

      {/* Call-to-Action Section */}
      <div className="flex flex-wrap gap-6 justify-center">
        <Link to="create-proposal">
        <Button
          text="Create Proposal"
          variant="primary"
          // onClick={() => alert('Redirect to Create Proposal')}
          additionalClasses="w-40"
        />
        </Link>
        <Button
          text="View Proposals"
          variant="secondary"
          onClick={() => alert('Redirect to View Proposals')}
          additionalClasses="w-40"
        />
        <Button
          text="Vote Now"
          variant="primary"
          onClick={() => alert('Redirect to Vote Page')}
          additionalClasses="w-40"
        />
      </div>

      {/* Features Section */}
      <section className="mt-16 grid grid-cols-1 md:grid-cols-3 gap-8 px-6 max-w-5xl">
        <div className="bg-white shadow-lg rounded-lg p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-blue-600 mb-4">Decentralized Governance</h3>
          <p className="text-gray-600">
            Secure and transparent voting powered by blockchain, ensuring fair and tamper-proof results.
          </p>
        </div>
        <div className="bg-white shadow-lg rounded-lg p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-blue-600 mb-4">Proposals Made Easy</h3>
          <p className="text-gray-600">
            Create and share proposals with your community seamlessly. Get feedback and take action.
          </p>
        </div>
        <div className="bg-white shadow-lg rounded-lg p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-blue-600 mb-4">Reward Participation</h3>
          <p className="text-gray-600">
            Incentivize users for active participation in governance and foster a vibrant ecosystem.
          </p>
        </div>
      </section>

      {/* Footer Section */}
      <footer className="mt-20 text-gray-500">
        <p>
          Built for communities, by communities. Powered by blockchain for a transparent future.
        </p>
      </footer>
    </div>
  );
};

export default HomePage;
