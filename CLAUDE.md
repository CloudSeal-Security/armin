# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains two main components:

1. **zgate_offline** - OpenZiti deployment package for offline installation
   - Contains .deb packages for OpenZiti components (controller, router, console)
   - Installation/uninstallation scripts for setting up OpenZiti infrastructure
   - Version: OpenZiti 1.5.4, Console 3.12.4

2. **ziti-console** - OpenZiti Admin Console (ZAC) source code
   - Angular 16-based web application for managing OpenZiti networks
   - Two deployment modes: Single Page Application (recommended) and Node.js server mode

## Architecture

### Ziti Console Structure

The console is organized into two Angular projects:

- **ziti-console-lib** (`projects/ziti-console-lib/`) - Angular library with core components
  - Data table components, visualizers, form components
  - Service classes for API communication
  - Shared assets (styles, icons, templates)

- **app-ziti-console** (`projects/app-ziti-console/`) - Main console application
  - Login/authentication components
  - Router configuration
  - Environment-specific configurations (Node.js vs browser)

Key directories:
- `src/lib/pages/` - Page components for different sections (identities, services, policies, etc.)
- `src/lib/features/` - Reusable feature components (data tables, modals, forms)
- `src/lib/services/` - API services and data management
- `src/lib/assets/` - Static assets (images, styles, scripts, templates)

## Common Commands

### Development

```bash
# Install dependencies (also builds ziti-console-lib automatically)
npm install

# Start development server
npm start
# or
ng serve ziti-console

# Build the library (required before building the app)
ng build ziti-console-lib

# Build everything (library + both app configurations)
npm run build

# Watch library changes and rebuild
npm run watch:lib
```

### Building

```bash
# Build library only
ng build ziti-console-lib

# Build console for production (SPA mode)
ng build ziti-console --configuration production

# Build console for Node.js deployment
ng build ziti-console-node

# Full build with library assets copying
npm run build-lib
```

### Testing

```bash
# Run unit tests
npm test
# or
ng test
```

### Docker

```bash
# Build Docker image
npm run docker:build

# Run Docker container
npm run docker:run

# Publish to Docker registry
npm run docker:publish
```

### Installation (zgate_offline)

```bash
# Install OpenZiti suite
cd zgate_offline
sudo ./install.sh

# Uninstall
sudo ./uninstall.sh
```

## Key Configuration Files

- `angular.json` - Angular workspace configuration
- `package.json` - Dependencies and scripts
- `tsconfig.json` - TypeScript configuration (strict mode with some exceptions)
- `projects/*/tsconfig.*.json` - Project-specific TypeScript configs

## API Integration

The console communicates with the OpenZiti Edge API. Key service classes:
- `ziti-controller-data.service.ts` - Main API communication service
- `ziti-domain-controller.service.ts` - Domain controller interface
- Various page-specific services in `pages/*/`

## Deployment

The console can be deployed as:
1. Static files served by the OpenZiti controller (recommended)
2. Standalone Node.js application (using `server.js`)
3. Docker container

For production deployment with base href:
```bash
./build.sh /path/to/base/href
```