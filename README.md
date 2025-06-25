# OpenZiti Admin Console (ZAC) & Offline Deployment Package

[中文版](./README.zh-TW.md) | English

This repository contains two main components for OpenZiti network management:
- **ziti-console**: Web-based admin console for managing OpenZiti networks
- **zgate_offline**: Offline deployment package for OpenZiti infrastructure

## 🚀 Quick Start

### For Development
```bash
# Install dependencies
npm install

# Start development server
npm start
# Access at http://localhost:4200
```

### For Offline Installation
```bash
cd zgate_offline
sudo ./install.sh
```

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Development](#development)
- [Building](#building)
- [Deployment](#deployment)
- [API Documentation](#api-documentation)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## ✨ Features

### Ziti Console (ZAC)
- **Comprehensive Management**: Manage identities, services, policies, routers, and configurations
- **Real-time Visualization**: Network topology and service maps with D3.js
- **Multi-deployment**: Supports SPA and Node.js server modes
- **OAuth2/OIDC Support**: Enterprise authentication integration
- **Responsive Design**: Works on desktop and mobile devices
- **Data Export**: Export configurations and reports to CSV
- **Advanced Filtering**: Complex search and filtering capabilities
- **Batch Operations**: Bulk actions on multiple entities

### Offline Deployment Package
- **Complete OpenZiti Stack**: Controller, Router, and Console components
- **Version**: OpenZiti 1.5.4, Console 3.12.4
- **Automated Installation**: Chinese-language installation scripts
- **Backup Utilities**: Database and PKI backup tools
- **Auto-enrollment**: Router auto-enrollment support
- **Console Patch**: Pre-built customized console (console_patch.tar)

## 🏗 Architecture

### Console Structure

```
ziti-console/
├── projects/
│   ├── ziti-console-lib/        # Reusable Angular library
│   │   └── src/lib/
│   │       ├── pages/           # Page components
│   │       │   ├── identities/  # Identity management
│   │       │   ├── services/    # Service configuration
│   │       │   ├── policies/    # Policy management
│   │       │   └── routers/     # Router management
│   │       ├── features/        # Reusable UI components
│   │       │   ├── data-table/  # Advanced data tables
│   │       │   ├── visualizer/  # Network visualizers
│   │       │   └── widgets/     # Form widgets
│   │       ├── services/        # API services
│   │       │   ├── ziti-controller-data.service.ts
│   │       │   └── settings.service.ts
│   │       └── assets/          # Static resources
│   └── app-ziti-console/        # Main application
│       └── src/
│           ├── app/             # App components
│           ├── environments/    # Environment configs
│           └── assets/          # App-specific assets
├── docker-images/               # Docker configurations
│   ├── zac/                     # Main console image
│   └── ziti-console-assets/     # Assets-only image
└── zgate_offline/               # Offline deployment
    ├── controller/              # Controller .deb package
    ├── router/                  # Router .deb package
    ├── console/                 # Console .deb package
    ├── backup/                  # Backup utilities
    └── install.sh              # Installation script
```

### Technology Stack

- **Frontend Framework**: Angular 16 with TypeScript
- **UI Components**: PrimeNG, Angular Material
- **Data Visualization**: D3.js, Chart.js, Leaflet
- **State Management**: RxJS
- **Styling**: SCSS, CSS Grid, Flexbox
- **Backend** (Node mode): Express.js, Helmet.js
- **Build Tools**: Angular CLI, ng-packagr, Webpack
- **Testing**: Jasmine, Karma
- **CI/CD**: Bitbucket Pipelines, Docker

## 📦 Installation

### Prerequisites

- **Node.js**: Version 16.x or higher
- **npm**: Version 8.x or higher
- **Angular CLI**: Version 16.x
- **Git**: For cloning the repository
- **Docker** (optional): For containerized deployment

### Development Setup

```bash
# Clone the repository
git clone <repository-url>
cd armin

# Install dependencies (automatically builds library)
npm install

# Start development server
npm start

# Access the application
# Default: http://localhost:4200
# With custom settings: http://localhost:4200?controllerAPI=https://your-controller:8441
```

### Environment Configuration

Configure your development environment by editing:
```typescript
// src/environments/environment.ts
export const environment = {
  production: false,
  apiPath: '/edge/management/v1',
  // Add your custom settings here
};
```

### Offline Installation (Linux)

The offline package supports Ubuntu/Debian-based systems:

```bash
# Navigate to offline package
cd zgate_offline

# Make scripts executable
chmod +x install.sh uninstall.sh

# Run installation (requires sudo)
sudo ./install.sh

# Follow the interactive prompts to:
# 1. Install OpenZiti Controller
# 2. Configure Controller settings
# 3. Install OpenZiti Router
# 4. Setup Router enrollment
# 5. Install Admin Console
```

## 💻 Development

### Development Server

```bash
# Start with default configuration
npm start

# Start with watch mode for library
npm run start:watch

# Start with specific configuration
ng serve ziti-console --configuration development
```

### Code Scaffolding

```bash
# Generate a new component
ng generate component features/my-component --project=ziti-console-lib

# Generate a new service
ng generate service services/my-service --project=ziti-console-lib

# Generate a new page
ng generate component pages/my-page --project=ziti-console-lib
```

### Watch Mode

For library development:
```bash
# Terminal 1: Watch library changes
npm run watch:lib

# Terminal 2: Run the application
npm start
```

### Code Style

The project uses:
- **ESLint** for code linting
- **Prettier** for code formatting
- **TypeScript** strict mode with some exceptions

```bash
# Run linting
npm run lint

# Fix linting issues
npm run lint:fix
```

### Testing

```bash
# Run unit tests
npm test

# Run tests with coverage
npm run test:coverage

# Run tests in watch mode
npm run test:watch

# Run e2e tests (if configured)
npm run e2e
```

## 🔨 Building

### Build Commands

```bash
# Build everything (library + both app configurations)
npm run build

# Build library only
ng build ziti-console-lib

# Build SPA version (recommended for production)
ng build ziti-console --configuration production

# Build Node.js server version
ng build ziti-console-node

# Build with custom base href
./build.sh /my/base/path

# Build with source maps
ng build ziti-console --source-map
```

### Build Outputs

- **Library**: `dist/ziti-console-lib/`
- **SPA Application**: `dist/app-ziti-console/`
- **Node Application**: `dist/app-ziti-console-node/`

### Docker Build

```bash
# Build Docker image
npm run docker:build

# Build with custom tag
docker build -t my-registry/ziti-console:latest .

# Build multi-platform image
docker buildx build --platform linux/amd64,linux/arm64 -t ziti-console:latest .
```

## 🚀 Deployment

### Option 1: Static Files (SPA - Recommended)

Perfect for CDN deployment or static web hosting:

```bash
# Build for production
ng build ziti-console --configuration production

# Deploy files from dist/app-ziti-console/
# Example with nginx:
cp -r dist/app-ziti-console/* /var/www/html/

# Example with AWS S3:
aws s3 sync dist/app-ziti-console/ s3://my-bucket/ --delete
```

### Option 2: Node.js Server

For environments requiring server-side features:

```bash
# Build Node.js version
ng build ziti-console-node

# Install production dependencies
cd dist/app-ziti-console-node
npm install --production

# Run server
node server.js

# Run with PM2
pm2 start server.js --name ziti-console

# Run with environment variables
ZAC_SERVER_PORT=8080 ZAC_NODE_MODULES_ROOT=./node_modules node server.js
```

### Option 3: Docker Container

```bash
# Run with Docker
docker run -d \
  --name ziti-console \
  -p 1408:1408 \
  -e ZAC_SERVER_PORT=1408 \
  -e ZITI_CTRL_ADVERTISED_HOST=controller.example.com \
  -e ZITI_CTRL_ADVERTISED_PORT=8441 \
  openziti/zac:latest

# Run with Docker Compose
docker-compose up -d
```

### Option 4: Kubernetes

```yaml
# Example Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ziti-console
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ziti-console
  template:
    metadata:
      labels:
        app: ziti-console
    spec:
      containers:
      - name: ziti-console
        image: openziti/zac:latest
        ports:
        - containerPort: 1408
        env:
        - name: ZAC_SERVER_PORT
          value: "1408"
```

### Option 5: OpenZiti Controller Integration

Deploy as part of the OpenZiti controller:

```bash
# Copy console files to controller's static directory
cp -r dist/app-ziti-console/* /opt/openziti/controller/static/

# Access via controller URL
# https://controller.example.com:8441/zac/
```

## 📡 API Documentation

### API Endpoints

The console communicates with OpenZiti Edge API:

- **Management API**: `/edge/management/v1/*`
  - Identities: `/identities`
  - Services: `/services`
  - Policies: `/service-policies`, `/edge-router-policies`
  - Routers: `/edge-routers`, `/transit-routers`

- **Client API**: `/edge/client/v1/*`
  - Sessions: `/sessions`
  - Services: `/services`

### Authentication

The console supports multiple authentication methods:

1. **Username/Password**: Default authentication
2. **Certificate**: mTLS authentication
3. **External JWT**: Third-party JWT tokens
4. **OAuth2/OIDC**: Enterprise SSO integration

### API Configuration

```typescript
// Configure API endpoints
const settings = {
  protocol: 'https',
  host: 'controller.example.com',
  port: 8441,
  apiPath: '/edge/management/v1'
};
```

## 📦 Creating console_patch.tar

The `console_patch.tar` file contains a customized build of the OpenZiti Admin Console for offline deployment. Here's how to create it:

### Step 1: Build the Console

```bash
# Navigate to the ziti-console directory
cd ziti-console

# Install dependencies
npm install

# Build for production
ng build ziti-console --configuration production
```

### Step 2: Prepare the Patch Directory

```bash
# Create patch directory with build output
mkdir -p console_patch
cp -r dist/app-ziti-console/* console_patch/

# Add custom assets (optional)
# For example, replace with custom branding:
# cp your-logo.png console_patch/assets/Z-Gate_Logo.png
# cp your-license.json console_patch/assets/license_number.json
```

### Step 3: Create the Tar Archive

```bash
# Create the tar file
tar -cf console_patch.tar console_patch/

# Move to the offline package directory
mv console_patch.tar zgate_offline/console/

# Clean up
rm -rf console_patch
```

### What's Included

The console_patch.tar contains:
- **Built Angular Application**: Optimized production build
- **Custom Branding**: Logo and theme customizations
- **License Configuration**: Deployment-specific settings
- **All Dependencies**: Bundled JavaScript, CSS, and assets

### Usage in Installation

The offline installer (`install.sh`) will:
1. Extract console_patch.tar
2. Remove the default console at `/opt/openziti/share/console`
3. Copy the customized console to the installation directory
4. Restart the ziti-controller service

## 🔧 Troubleshooting

### Common Issues

#### Build Errors

```bash
# Clear cache and rebuild
rm -rf node_modules dist
npm install
npm run build

# Fix peer dependency issues
npm install --legacy-peer-deps
```

#### Runtime Errors

1. **CORS Issues**: Ensure the controller allows the console origin
2. **Certificate Errors**: Add controller certificate to trusted store
3. **API Connection**: Verify controller is accessible

#### Development Issues

```bash
# Port already in use
# Kill process on port 4200
lsof -ti:4200 | xargs kill -9

# Memory issues during build
export NODE_OPTIONS="--max-old-space-size=4096"
npm run build
```

### Debug Mode

Enable debug logging:
```typescript
// In browser console
localStorage.setItem('debug', 'true');
location.reload();
```

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Development Process

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Coding Standards

- Follow Angular style guide
- Use TypeScript strict mode
- Write unit tests for new features
- Update documentation as needed
- Add JSDoc comments for public APIs

### Commit Convention

Follow conventional commits:
```
feat: add new feature
fix: fix bug in component
docs: update README
style: format code
refactor: refactor service
test: add unit tests
chore: update dependencies
```

### Testing Requirements

- Maintain >80% code coverage
- All tests must pass
- Add tests for new features
- Update tests for modified code

## 📄 License

[License information - Add your license here]

## 🆘 Support

- **Documentation**: [OpenZiti Docs](https://openziti.io)
- **Issues**: [GitHub Issues](https://github.com/openziti/ziti-console/issues)
- **Community**: [OpenZiti Discourse](https://openziti.discourse.group)
- **Security**: Report security issues to security@openziti.org

## 🔗 Related Projects

- [OpenZiti](https://github.com/openziti/ziti): Zero Trust Network Software
- [OpenZiti Controller](https://github.com/openziti/ziti/tree/main/controller): Network Controller
- [OpenZiti Router](https://github.com/openziti/ziti/tree/main/router): Edge and Transit Routers
- [OpenZiti SDK](https://github.com/openziti/sdk-golang): Go SDK for OpenZiti

## 📊 Version History

- **Current Version**: Console 3.12.4, OpenZiti 1.5.4
- **Angular Version**: 16.x
- **Node.js Support**: 16.x and higher

---

Made with ❤️ by the OpenZiti Community