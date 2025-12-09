# 🚀 Panduan Instalasi DeFi Protocol

Panduan lengkap untuk instalasi dan setup frontend dan backend DeFi Protocol dalam satu output.

## 📋 Daftar Isi

1. [Prasyarat](#prasyarat)
2. [Setup Database](#setup-database)
3. [Setup Backend](#setup-backend)
4. [Setup Frontend](#setup-frontend)
5. [Menjalankan Aplikasi](#menjalankan-aplikasi)
6. [Troubleshooting](#troubleshooting)

## 📋 Prasyarat

Sebelum memulai, pastikan Anda telah menginstall:

- **Node.js** (v18 atau lebih baru) - [Download](https://nodejs.org/)
- **npm** atau **yarn**
- **PostgreSQL** (v12 atau lebih baru) - [Download](https://www.postgresql.org/download/)
- **MetaMask** (browser extension) - [Download](https://metamask.io/download/)
- **Git**

### Install Node.js dan PostgreSQL

#### Windows
1. Download dan install Node.js dari https://nodejs.org/
2. Download dan install PostgreSQL dari https://www.postgresql.org/download/windows/
3. Setup PostgreSQL dengan password untuk user `postgres`

#### macOS
```bash
# Install Homebrew jika belum ada
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Node.js
brew install node

# Install PostgreSQL
brew install postgresql
brew services start postgresql
```

#### Linux (Ubuntu/Debian)
```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

## 🗄️ Setup Database

### 1. Create Database

```bash
# Login ke PostgreSQL (Linux/macOS)
sudo -u postgres psql

# Atau di Windows, buka PostgreSQL Command Line
# Masuk ke PostgreSQL dengan user postgres
```

```sql
-- Create database
CREATE DATABASE defi_protocol;

-- Create user
CREATE USER defi_user WITH PASSWORD 'your_password_here';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE defi_protocol TO defi_user;

-- Exit PostgreSQL
\q
```

### 2. Run Migrations

```bash
# Masuk ke database
psql -U defi_user -d defi_protocol

# Run migrations (dari folder project root)
\i database/schema.sql
\i database/views.sql
\i database/functions.sql

# Atau menggunakan migration files
\i database/migrations/001_initial_schema.sql
\i database/migrations/002_views_and_functions.sql

# Exit
\q
```

## ⚙️ Setup Backend

### 1. Install Dependencies

```bash
# Masuk ke folder backend
cd backend

# Install dependencies
npm install
```

### 2. Konfigurasi Environment Variables

```bash
# Copy file .env.example ke .env
cp .env.example .env

# Edit file .env dengan konfigurasi Anda
# Windows: notepad .env
# Linux/macOS: nano .env
```

Edit file `backend/.env` dengan konfigurasi berikut:

```env
# Server Configuration
PORT=3001
NODE_ENV=development

# Blockchain Configuration
RPC_URL=http://localhost:8545
PRIVATE_KEY=your_private_key_here
CHAIN_ID=1337

# Contract Addresses (Update setelah deployment smart contract)
DEFI_PROTOCOL_ADDRESS=0x0000000000000000000000000000000000000000
DEX_ADDRESS=0x0000000000000000000000000000000000000000
YIELD_FARM_ADDRESS=0x0000000000000000000000000000000000000000
FLASH_LOAN_ADDRESS=0x0000000000000000000000000000000000000000
GOVERNANCE_ADDRESS=0x0000000000000000000000000000000000000000
ORACLE_ADDRESS=0x0000000000000000000000000000000000000000
PROTOCOL_TOKEN_ADDRESS=0x0000000000000000000000000000000000000000

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=defi_protocol
DB_USER=defi_user
DB_PASSWORD=your_password_here

# API Keys (Optional)
ETHERSCAN_API_KEY=your_etherscan_api_key
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key
```

### 3. Compile Smart Contracts

**Penting**: Anda perlu compile smart contract terlebih dahulu untuk mendapatkan ABI files.

```bash
# Install Hardhat (jika belum ada)
npm install -g hardhat

# Di folder project root, compile contracts
npx hardhat compile

# Copy ABI files dari artifacts ke backend/src/abis/
# Setelah compile, copy file ABI dari artifacts ke backend/src/abis/
```

### 4. Update Contract ABIs

Setelah compile smart contract, copy file ABI dari folder `artifacts` ke `backend/src/abis/`:

```bash
# Contoh untuk Hardhat
cp artifacts/contracts/DeFiProtocol.sol/DeFiProtocol.json backend/src/abis/DeFiProtocol.json
cp artifacts/contracts/AMMDEX.sol/AMMDEX.json backend/src/abis/AMMDEX.json
cp artifacts/contracts/YieldFarm.sol/YieldFarm.json backend/src/abis/YieldFarm.json
cp artifacts/contracts/FlashLoanProvider.sol/FlashLoanProvider.json backend/src/abis/FlashLoanProvider.json
cp artifacts/contracts/Governance.sol/Governance.json backend/src/abis/Governance.json
cp artifacts/contracts/PriceOracle.sol/PriceOracle.json backend/src/abis/PriceOracle.json
```

**Catatan**: Jika Anda belum compile smart contract, Anda bisa menggunakan placeholder ABI files yang sudah disediakan di `backend/src/abis/`. Namun, untuk production, Anda harus compile smart contract terlebih dahulu.

### 5. Deploy Smart Contracts

Deploy smart contract ke blockchain (local atau testnet) dan update address di file `.env`:

```bash
# Deploy menggunakan Hardhat (contoh)
npx hardhat run scripts/deploy.js --network localhost

# Update address di .env setelah deployment
```

### 6. Start Backend Server

```bash
# Development mode
npm run dev

# Production mode
npm start
```

Backend server akan berjalan di `http://localhost:3001`

**Test Backend**:
```bash
# Test health endpoint
curl http://localhost:3001/health
```

## 🎨 Setup Frontend

### 1. Install Dependencies

```bash
# Masuk ke folder frontend
cd frontend

# Install dependencies
npm install
```

### 2. Konfigurasi Environment Variables

Buat file `.env.local` di folder `frontend`:

```bash
# Copy dari example
cp .env.local.example .env.local

# Edit file .env.local
# Windows: notepad .env.local
# Linux/macOS: nano .env.local
```

Edit file `frontend/.env.local`:

```env
# API URL
NEXT_PUBLIC_API_URL=http://localhost:3001/api

# Blockchain Configuration
NEXT_PUBLIC_RPC_URL=http://localhost:8545
NEXT_PUBLIC_CHAIN_ID=1337

# Contract Addresses (Update setelah deployment)
NEXT_PUBLIC_DEFI_PROTOCOL_ADDRESS=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_DEX_ADDRESS=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_YIELD_FARM_ADDRESS=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_FLASH_LOAN_ADDRESS=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_GOVERNANCE_ADDRESS=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_ORACLE_ADDRESS=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_PROTOCOL_TOKEN_ADDRESS=0x0000000000000000000000000000000000000000
```

### 3. Start Frontend Development Server

```bash
# Development mode
npm run dev

# Production mode
npm run build
npm start
```

Frontend akan berjalan di `http://localhost:3000`

## 🚀 Menjalankan Aplikasi

### Langkah-langkah Menjalankan

1. **Start Database** (Pastikan PostgreSQL running)
   ```bash
   # Check status
   sudo systemctl status postgresql  # Linux
   brew services list  # macOS
   ```

2. **Start Backend**
   ```bash
   cd backend
   npm run dev
   ```
   Backend akan berjalan di `http://localhost:3001`

3. **Start Frontend**
   ```bash
   cd frontend
   npm run dev
   ```
   Frontend akan berjalan di `http://localhost:3000`

4. **Akses Aplikasi**
   - **Frontend**: http://localhost:3000
   - **Backend API**: http://localhost:3001
   - **Health Check**: http://localhost:3001/health
   - **App Page**: http://localhost:3000/app

### Struktur Aplikasi

- **Landing Page**: http://localhost:3000 (Halaman utama dengan informasi protocol)
- **App Page**: http://localhost:3000/app (Halaman aplikasi dengan fitur DEX, Farm, Governance)

## 🔧 Troubleshooting

### Backend Issues

#### Error: Cannot connect to database
```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check database connection
psql -U defi_user -d defi_protocol -h localhost

# Check password di .env file
```

#### Error: Contract address not set
```bash
# Pastikan contract addresses sudah diisi di .env
# Deploy contract terlebih dahulu jika belum
# Atau gunakan address dari deployment sebelumnya
```

#### Error: Invalid ABI
```bash
# Pastikan ABI files sudah di-copy dari artifacts
# Compile contract terlebih dahulu
npx hardhat compile

# Copy ABI files ke backend/src/abis/
```

#### Error: Module not found
```bash
# Install dependencies
cd backend
npm install
```

### Frontend Issues

#### Error: Cannot connect to API
```bash
# Check backend is running
curl http://localhost:3001/health

# Check NEXT_PUBLIC_API_URL in .env.local
# Pastikan backend berjalan di port 3001
```

#### Error: MetaMask not found
```bash
# Install MetaMask extension di browser
# https://metamask.io/download/
# Connect wallet di aplikasi
```

#### Error: Network error
```bash
# Check RPC URL is correct
# Check chain ID matches your network
# Pastikan blockchain node running (jika menggunakan local node)
```

#### Error: Module not found
```bash
# Install dependencies
cd frontend
npm install
```

### Database Issues

#### Error: Permission denied
```bash
# Grant permissions
sudo -u postgres psql
GRANT ALL PRIVILEGES ON DATABASE defi_protocol TO defi_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO defi_user;
\q
```

#### Error: Table does not exist
```bash
# Run migrations
psql -U defi_user -d defi_protocol -f database/schema.sql
psql -U defi_user -d defi_protocol -f database/views.sql
psql -U defi_user -d defi_protocol -f database/functions.sql
```

## 📝 Testing

### Test Backend API

```bash
# Test health endpoint
curl http://localhost:3001/health

# Test DEX endpoint
curl http://localhost:3001/api/dex/pools

# Test Farm endpoint
curl http://localhost:3001/api/farm/farms

# Test Governance endpoint
curl http://localhost:3001/api/governance/proposals
```

### Test Frontend

```bash
# Run tests (jika ada)
cd frontend
npm test

# Run lint
npm run lint
```

## 🔒 Security Considerations

1. **Never commit `.env` files** - Gunakan `.env.example` sebagai template
2. **Use strong passwords** untuk database
3. **Keep private keys secure** - Jangan share private keys
4. **Use environment variables** untuk sensitive data
5. **Enable CORS** hanya untuk domain yang dipercaya
6. **Use HTTPS** di production
7. **Validate input** di backend dan frontend
8. **Use rate limiting** untuk API endpoints

## 📚 Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Node.js Documentation](https://nodejs.org/docs/)
- [Next.js Documentation](https://nextjs.org/docs)
- [Ethers.js Documentation](https://docs.ethers.org/)
- [Hardhat Documentation](https://hardhat.org/docs)

## 🆘 Support

Jika mengalami masalah, silakan:
1. Check troubleshooting section di atas
2. Check logs di backend dan frontend
3. Check database connection
4. Check contract addresses dan ABIs
5. Check network configuration

## 📄 License

MIT License

## 🎯 Quick Start Summary

```bash
# 1. Setup Database
sudo -u postgres psql
CREATE DATABASE defi_protocol;
CREATE USER defi_user WITH PASSWORD 'password';
GRANT ALL PRIVILEGES ON DATABASE defi_protocol TO defi_user;
\q

# 2. Run Migrations
psql -U defi_user -d defi_protocol -f database/schema.sql

# 3. Setup Backend
cd backend
npm install
cp .env.example .env
# Edit .env dengan konfigurasi Anda
npm run dev

# 4. Setup Frontend
cd frontend
npm install
cp .env.local.example .env.local
# Edit .env.local dengan konfigurasi Anda
npm run dev

# 5. Akses Aplikasi
# Frontend: http://localhost:3000
# Backend: http://localhost:3001
```

---

**Selamat! Aplikasi DeFi Protocol Anda siap digunakan! 🎉**



