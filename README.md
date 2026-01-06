# PostgreSQL Development Stack

A complete PostgreSQL development environment with REST API, admin interface, and automated backups. This stack includes PostgreSQL, PostgREST (REST API), PgAdmin, Swagger UI, and Nginx as a reverse proxy with SSL support.

## 🏗️ Architecture

This project provides a full-stack PostgreSQL development environment with the following components:

- **PostgreSQL**: Main database server
- **PostgREST**: Automatic REST API generator for PostgreSQL
- **PgAdmin**: Web-based PostgreSQL administration tool
- **Swagger UI**: Interactive API documentation
- **Nginx**: Reverse proxy with SSL/TLS support
- **Backup Service**: Automated database backups with scheduling

## 📋 Prerequisites

- Docker and Docker Compose installed
- OpenSSL (for generating SSL certificates)
- Basic knowledge of PostgreSQL and REST APIs

## 🚀 Quick Start

### 1. Clone or navigate to the project directory

```bash
cd /path/to/db-postgres
```

### 2. Create environment file

Copy the `.env.example` file to `.env` and configure the variables:

```bash
cp .env.example .env
```

Edit `.env` and set your desired values, especially:
- Database credentials (`DB_USER`, `DB_PASSWORD`, `DB_NAME`)
- JWT secret (`PGRST_JWT_SECRET`)
- API master key (`API_MASTER_KEY`)
- PgAdmin credentials (`PGADMIN_MAIL`, `PGADMIN_PW`)

### 3. Generate SSL certificates

The Nginx proxy requires SSL certificates. Create them in the `nginx_ssl` directory using the appropriate method for your operating system:

#### Linux / macOS

```bash
mkdir -p nginx_ssl
cd nginx_ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx.key \
  -out nginx.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
cd ..
```

#### Windows (PowerShell)

```powershell
New-Item -ItemType Directory -Force -Path nginx_ssl
cd nginx_ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
  -keyout nginx.key `
  -out nginx.crt `
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
cd ..
```

**Note for Windows**: If OpenSSL is not installed, you can:
- Install it via [Git for Windows](https://git-scm.com/download/win) (includes OpenSSL)
- Install via [Chocolatey](https://chocolatey.org/): `choco install openssl`
- Install via [WSL](https://learn.microsoft.com/en-us/windows/wsl/) and use the Linux method

#### Windows (Command Prompt / CMD)

```cmd
mkdir nginx_ssl 2>nul
cd nginx_ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx.key -out nginx.crt -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
cd ..
```

**Note**: These are self-signed certificates for development. Browsers will show a security warning, which you can safely ignore for local development.

### 4. Start the services

```bash
docker-compose up -d
```

This will start all services in detached mode. The first startup may take a few minutes as PostgreSQL initializes and runs the bootstrap script.

### 5. Verify services are running

```bash
docker-compose ps
```

All services should show as "Up" and healthy.

## 🌐 Access Points

Once the services are running, you can access:

- **Web Interface**: `https://localhost/` - Customer management interface (uses the `customers` table)
- **PgAdmin**: `https://localhost/pgadmin/` - Database administration
- **API Endpoint**: `https://localhost/api/` - REST API base URL
- **Swagger UI**: `https://localhost/swagger/` - Interactive API documentation

**Important**: Use `https://` (not `http://`) as the Nginx proxy only listens on port 443.

## 🔐 Authentication

### Getting a JWT Token

1. Access Swagger UI at `https://localhost/swagger/`
2. Find the `/rpc/login` endpoint
3. Execute it with your `API_MASTER_KEY` as the `api_key` parameter
4. Copy the returned JWT token

### Using the Token

Include the token in API requests using the `Authorization` header:

```bash
# Example: List all customers
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://localhost/api/customers

# Example: Get a specific customer
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://localhost/api/customers?id=eq.1
```

Or in the Swagger UI, click "Authorize" and paste your token.

## 📊 Database Setup

### Initial Bootstrap

The initialization scripts run automatically on first database initialization in alphabetical order:

**`init-scripts/01-bootstrap.sql`** - Sets up the database foundation:
- `extensions` schema with `pgcrypto` extension
- `auth` schema with JWT signing functions
- `web_anon` and `api_user` roles
- `login()` function for authentication
- `setup_table_api()` procedure for table configuration

**`init-scripts/02-data.sql`** - Creates sample data:
- Creates the `customers` table with the following structure:
  - `id` (SERIAL PRIMARY KEY)
  - `full_name` (TEXT NOT NULL)
  - `email` (TEXT UNIQUE NOT NULL)
  - `city` (TEXT)
  - `created_at` (TIMESTAMP WITH TIME ZONE)
- Inserts sample customer records
- Automatically configures the table for API access using `setup_table_api()`

The web interface at `https://localhost/` is pre-configured to work with this `customers` table.

### Creating Your Own Tables

After creating tables in PostgreSQL, use the `setup_table_api()` procedure to configure them for API access:

```sql
-- Example: Create a table
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    city TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Configure the table for API access
CALL setup_table_api('customers');
```

This procedure:
- Grants appropriate permissions to `web_anon` and `api_user` roles
- Enables Row Level Security (RLS)
- Creates a policy allowing `api_user` full access

### Accessing the Database

You can access the database directly using:

```bash
docker exec -it postgres_db psql -U your_db_user -d your_db_name
```

Or use PgAdmin at `https://localhost/pgadmin/` with:
- Host: `db` (container name)
- Port: `5432`
- Username: Your `DB_USER`
- Password: Your `DB_PASSWORD`

## 🔄 API Usage

### PostgREST API Features

PostgREST automatically generates REST endpoints for all tables in the `public` schema. The `customers` table is available by default. Common operations:

**List all customers:**
```bash
GET /api/customers
Authorization: Bearer YOUR_JWT_TOKEN
```

**Filter customers:**
```bash
GET /api/customers?city=eq.New York
Authorization: Bearer YOUR_JWT_TOKEN
```

**Get a specific customer:**
```bash
GET /api/customers?id=eq.1
Authorization: Bearer YOUR_JWT_TOKEN
```

**Create a customer:**
```bash
POST /api/customers
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "full_name": "John Doe",
  "email": "john@example.com",
  "city": "New York"
}
```

**Update a customer:**
```bash
PATCH /api/customers?id=eq.1
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "city": "Los Angeles"
}
```

**Delete a customer:**
```bash
DELETE /api/customers?id=eq.1
Authorization: Bearer YOUR_JWT_TOKEN
```

### Custom Functions

Call PostgreSQL functions via the API:

```bash
POST /api/rpc/function_name
Content-Type: application/json

{
  "param1": "value1"
}
```

## 💾 Backups

### Automatic Backups

Backups run automatically according to the `BACKUP_SCHEDULE` in your `.env` file (default: daily at 2 AM). Backups are stored in the `./backups` directory.

### Manual Backup

Run a manual backup using the provided script:

```bash
./backup_now.command
```

Or on Linux:

```bash
bash backup_now.command
```

This script:
1. Executes a backup via the backup container
2. Cleans up old backups (older than `BACKUP_KEEP_DAYS`)
3. Refreshes the PostgREST API cache

### Backup Files

Backups are stored as compressed SQL files in `./backups/` with the format:
```
backup-DB_NAME-YYYY-MM-DD.sql.gz
```

### Restoring a Backup

To restore a backup:

```bash
# Extract if needed
gunzip backups/backup-dbname-2024-01-01.sql.gz

# Restore
docker exec -i postgres_db psql -U your_db_user -d your_db_name < backups/backup-dbname-2024-01-01.sql
```

## 🛠️ Configuration

### Environment Variables

All configuration is done through the `.env` file. Key variables:

- **Database**: `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_IMAGE_TAG`
- **API**: `PGRST_JWT_SECRET`, `API_MASTER_KEY`, `API_IMAGE_TAG`
- **PgAdmin**: `PGADMIN_MAIL`, `PGADMIN_PW`, `PGADMIN_IMAGE_TAG`
- **Backups**: `BACKUP_SCHEDULE`, `BACKUP_KEEP_DAYS`

See `.env.example` for all available options.

### Nginx Configuration

The Nginx configuration is in `nginx.conf`. It:
- Serves static files from `www/` at the root path
- Proxies `/pgadmin/` to PgAdmin
- Proxies `/api/` to PostgREST with CORS headers
- Proxies `/swagger/` to Swagger UI
- Uses SSL certificates from `nginx_ssl/`

### Modifying Services

To modify service configurations:
1. Edit `docker-compose.yaml` for service settings
2. Edit `nginx.conf` for proxy configuration
3. Edit `init-scripts/01-bootstrap.sql` for database foundation setup
4. Edit `init-scripts/02-data.sql` for sample data and tables
5. Restart services: `docker-compose restart`

**Note**: Changes to initialization scripts (`01-bootstrap.sql` and `02-data.sql`) will only take effect on a fresh database. To apply changes to an existing database, you'll need to either:
- Drop and recreate the database volume: `docker-compose down -v && docker-compose up -d`
- Or manually run the SQL scripts via PgAdmin or `psql`

## 🔧 Troubleshooting

### Services won't start

1. Check if ports are already in use:
   ```bash
   lsof -i :443
   ```

2. Verify Docker is running:
   ```bash
   docker ps
   ```

3. Check service logs:
   ```bash
   docker-compose logs [service_name]
   ```

### Database connection issues

1. Ensure the database container is healthy:
   ```bash
   docker-compose ps
   ```

2. Check database logs:
   ```bash
   docker-compose logs db
   ```

3. Verify credentials in `.env` match what you're using

### SSL certificate errors

- For development, accept the browser warning for self-signed certificates
- Ensure `nginx_ssl/nginx.crt` and `nginx_ssl/nginx.key` exist
- Regenerate certificates if needed (see Quick Start step 3)

### API not responding

1. Check PostgREST logs:
   ```bash
   docker-compose logs api
   ```

2. Refresh the API schema cache:
   ```bash
   docker kill -s SIGUSR1 postgrest_api
   ```

3. Verify the database schema is accessible

### Backup issues

1. Check backup container logs:
   ```bash
   docker-compose logs backups
   ```

2. Verify the `backups/` directory has write permissions
3. Check disk space availability

## 🛑 Stopping Services

To stop all services:

```bash
docker-compose down
```

To stop and remove volumes (⚠️ **WARNING**: This deletes all data):

```bash
docker-compose down -v
```

## 📁 Project Structure

```
.
├── docker-compose.yaml      # Docker services configuration
├── nginx.conf               # Nginx reverse proxy configuration
├── .env                     # Environment variables (create from .env.example)
├── .env.example             # Example environment variables
├── backup_now.command       # Manual backup script
├── backups/                 # Backup files directory
├── init-scripts/
│   ├── 01-bootstrap.sql     # Database foundation setup (schemas, roles, functions)
│   └── 02-data.sql          # Sample table creation and seed data (customers table)
├── nginx_ssl/               # SSL certificates directory
│   ├── nginx.crt
│   └── nginx.key
└── www/
    └── index.html           # Web interface
```

## 🔒 Security Notes

⚠️ **This setup is for DEVELOPMENT ONLY**

- Self-signed SSL certificates are used
- Default credentials should be changed in production
- The API master key should be kept secret
- JWT secret should be strong and random
- Row Level Security (RLS) is enabled but policies should be reviewed
- CORS is configured to allow all origins (`*`) - restrict this in production

For production deployments:
- Use proper SSL certificates from a CA
- Implement proper authentication and authorization
- Review and customize RLS policies
- Use secrets management
- Enable proper logging and monitoring

## 📚 Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PostgREST Documentation](https://postgrest.org/)
- [PgAdmin Documentation](https://www.pgadmin.org/docs/)
- [Nginx Documentation](https://nginx.org/en/docs/)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is provided as-is for development purposes.

