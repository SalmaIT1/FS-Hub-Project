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
    console.log('Running migration: Add is_active column to employees table');
    
    // Read migration file
    const migrationPath = path.join(__dirname, 'add_is_active_column.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
    
    // Execute migration
    await connection.execute(migrationSQL);
    console.log('✅ Migration completed successfully!');
    
  } catch (error) {
    if (error.code === 'ER_DUP_FIELDNAME') {
      console.log('✅ Column is_active already exists - no migration needed');
    } else {
      console.error('❌ Migration failed:', error);
    }
  } finally {
    await connection.end();
  }
}

runMigration();
