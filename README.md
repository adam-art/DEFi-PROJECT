# 🚀 DeFi Protocol - Complete Web Application

Platform DeFi lengkap dengan DEX, Yield Farming, Flash Loans, dan Governance yang terintegrasi dalam satu aplikasi web.

## 📋 Deskripsi

DeFi Protocol adalah platform DeFi yang menyediakan:

- **AMM DEX (Automated Market Maker)**: Swap tokens, tambah/keluarkan liquidity pools
- **Yield Farming**: Stake LP tokens untuk mendapatkan rewards
- **Flash Loans**: Pinjaman flash untuk arbitrage dan trading strategies
- **Governance**: Sistem voting dan proposal untuk pengambilan keputusan protocol
- **Price Oracle**: Update dan query harga token

## 🏗️ Struktur Proyek

```
SMART CONTRACT PROJECT/
├── backend/                 # Backend API Server
│   ├── src/
│   │   ├── server.js       # Main server file
│   │   ├── config/         # Configuration files
│   │   ├── routes/         # API routes
│   │   └── abis/           # Contract ABIs
│   ├── package.json
│   └── .env.example
│
├── frontend/                # Frontend Next.js Application
│   ├── app/                # Next.js app router
│   │   ├── page.tsx        # Landing page
│   │   └── app/            # App page
│   ├── components/         # React components
│   │   ├── DEX/           # DEX components
│   │   ├── Farm/          # Yield farm components
│   │   └── Governance/    # Governance components
│   ├── lib/               # Utility libraries
│   ├── package.json
│   └── .env.local.example
│
├── database/               # Database schema and migrations
│   ├── schema.sql
│   ├── views.sql
│   ├── functions.sql
│   └── migrations/
│
├── DeFiProtocol.sol       # Main smart contract
├── README_INSTALASI.md    # Installation guide (Bahasa Indonesia)
└── INSTALLATION.md        # Installation guide (English)
```

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install backend dependencies
cd backend
npm install

# Install frontend dependencies
cd ../frontend
npm install
```

### 2. Setup Database

```bash
# Create database
sudo -u postgres psql
CREATE DATABASE defi_protocol;
CREATE USER defi_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE defi_protocol TO defi_user;
\q

# Run migrations
psql -U defi_user -d defi_protocol -f database/schema.sql
```

### 3. Configure Environment Variables

```bash
# Backend
cd backend
cp .env.example .env
# Edit .env with your configuration

# Frontend
cd ../frontend
cp .env.local.example .env.local
# Edit .env.local with your configuration
```

### 4. Start Services

```bash
# Start backend (Terminal 1)
cd backend
npm run dev

# Start frontend (Terminal 2)
cd frontend
npm run dev
```

### 5. Access Application

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:3001
- **App Page**: http://localhost:3000/app

## 📖 Dokumentasi Lengkap

Untuk panduan instalasi lengkap, silakan baca:

- **Bahasa Indonesia**: [README_INSTALASI.md](./README_INSTALASI.md)
- **English**: [INSTALLATION.md](./INSTALLATION.md)

## 🔧 Teknologi yang Digunakan

### Backend
- **Node.js** - Runtime environment
- **Express.js** - Web framework
- **Ethers.js** - Ethereum library
- **PostgreSQL** - Database
- **Axios** - HTTP client

### Frontend
- **Next.js** - React framework
- **React** - UI library
- **Ethers.js** - Ethereum library
- **Axios** - HTTP client
- **React Hot Toast** - Toast notifications

### Smart Contracts
- **Solidity** - Smart contract language
- **OpenZeppelin** - Security libraries
- **Hardhat** - Development environment

## 📁 Fitur Utama

### 1. DEX (Decentralized Exchange)
- Swap tokens
- Add/Remove liquidity
- Create liquidity pools
- Get swap quotes

### 2. Yield Farming
- Deposit LP tokens
- Withdraw LP tokens
- Harvest rewards
- View farm information

### 3. Governance
- Create proposals
- Vote on proposals
- Execute proposals
- View proposal status

### 4. Flash Loans
- Request flash loans
- Deposit to flash loan pool
- View reserves

### 5. Price Oracle
- Get token prices
- Update token prices
- Get price in ETH

## 🔒 Security

- Smart contracts menggunakan OpenZeppelin libraries
- ReentrancyGuard untuk mencegah reentrancy attacks
- AccessControl untuk role-based access
- Pausable untuk emergency stops
- Input validation di backend dan frontend

## 🧪 Testing

```bash
# Test backend API
curl http://localhost:3001/health

# Test frontend
cd frontend
npm test
```

## 📝 License

MIT License

## 🆘 Support

Jika mengalami masalah, silakan:
1. Check [Troubleshooting](./README_INSTALASI.md#troubleshooting) section
2. Check logs di backend dan frontend
3. Check database connection
4. Check contract addresses dan ABIs

## 📚 Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Node.js Documentation](https://nodejs.org/docs/)
- [Next.js Documentation](https://nextjs.org/docs)
- [Ethers.js Documentation](https://docs.ethers.org/)
- [Hardhat Documentation](https://hardhat.org/docs)

## 🎯 Next Steps

1. Deploy smart contracts ke testnet/mainnet
2. Update contract addresses di environment variables
3. Setup production database
4. Configure HTTPS
5. Setup monitoring dan logging
6. Deploy frontend dan backend ke production

---

**Selamat menggunakan DeFi Protocol! 🎉**



