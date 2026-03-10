const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

async function runMigration() {
  const connection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'fs_hub'
  });

  try {
    console.log('Running migration: Create postes table');
    
    // Read migration file
    const migrationPath = path.join(__dirname, 'create_postes_table.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
    
    // Execute migration
    await connection.execute(migrationSQL);
    console.log('✅ Postes table migration completed successfully!');
    
  } catch (error) {
    if (error.code === 'ER_TABLE_EXISTS_ERROR') {
      console.log('✅ Postes table already exists - no migration needed');
    } else {
      console.error('❌ Migration failed:', error);
    }
  } finally {
    await connection.end();
  }
}

runMigration();
