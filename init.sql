-- Create database if it doesn't exist
DO
$$
BEGIN
   IF NOT EXISTS (
      SELECT
      FROM   pg_catalog.pg_database
      WHERE  datname = 'mydatabase'
      ) THEN
      CREATE DATABASE mydatabase;
   END IF;
END
$$;

-- Create user with specified password
DO
$$
BEGIN
   IF NOT EXISTS (
      SELECT
      FROM   pg_catalog.pg_roles
      WHERE  rolname = 'tvacadmin'
      ) THEN
      CREATE USER tvacadmin WITH PASSWORD 'tvacpassword';
   END IF;
END
$$;

-- Connect to the database and set up PostGIS
\c mydatabase tvacadmin
CREATE EXTENSION IF NOT EXISTS postgis;

-- Reindex database and refresh collation version to handle collation mismatch
REINDEX DATABASE mydatabase;
ALTER DATABASE mydatabase REFRESH COLLATION VERSION;

-- Grant necessary permissions to the user
ALTER ROLE tvacadmin CREATEDB;

-- Grant privileges on the database to the user
GRANT ALL PRIVILEGES ON DATABASE mydatabase TO tvacadmin;
