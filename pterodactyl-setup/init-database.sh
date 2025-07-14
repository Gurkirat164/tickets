#!/bin/bash

# Database initialization script for Tickets Bot

echo "Initializing Tickets Bot databases..."

# Main database schema
psql -h $POSTGRES_HOST -U tickets_user -d tickets_main << EOF
-- The application will create its own schemas, but you can pre-create tables here if needed
-- This is handled by the application's create_schema() functions
EOF

# Patreon database schema (if using Patreon integration)
psql -h $POSTGRES_HOST -U tickets_user -d tickets_patreon << EOF
-- Patreon integration schema will be created by the patreon-proxy service
EOF

# Vote listener database schema (if using vote rewards)
psql -h $POSTGRES_HOST -U tickets_user -d tickets_votes << EOF
-- Vote tracking schema will be created by the vote_listener service
EOF

echo "Database initialization completed!"
echo "Note: The applications will create their own schemas on first run."
