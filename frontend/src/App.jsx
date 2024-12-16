import { useState } from 'react';
import reactLogo from './assets/react.svg';
import './App.css';
import * as MicroStacks from '@micro-stacks/react';
import { WalletConnectButton } from './components/wallet-connect-button.jsx';
import { UserCard } from './components/user-card.jsx';
import { Logo } from './components/ustx-logo.jsx';
import { NetworkToggle } from './components/network-toggle.jsx';
import HomePage from './pages/HomePage.jsx';
import CreateProposalPage from './pages/CreateProposalPage.jsx';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';

function Contents() {
  return (
    <>
      <div class="card">
        <UserCard />
        <WalletConnectButton />
        <NetworkToggle />
      </div>
    </>
  );
}

export default function App() {
  return (
    <MicroStacks.ClientProvider
      appName={'Evoting System'}
      appIconUrl={reactLogo}
    >
      {/* <Contents /> */}
      <Router>
        <Routes>
          <Route
            path="/"
            element={<HomePage />}
          />
          <Route
            path="/create-proposal"
            element={<CreateProposalPage />}
          />

          {/* Add other pages here */}
        </Routes>
      </Router>
    </MicroStacks.ClientProvider>
  );
}
