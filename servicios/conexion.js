const mysql = require('mysql2/promise');
const { createClient } = require('@supabase/supabase-js');
const mssql = require('mssql');
require('dotenv').config();

// ==========================================
// CLIENTES SUPABASE
// ==========================================
const supabaseCampo = createClient(
  process.env.SUPABASE_EMPA_URL || 'https://veqpyhifwubcdxocckmf.supabase.co',
  process.env.SUPABASE_EMPA_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZlcXB5aGlmd3ViY2R4b2Nja21mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NzI5NzAsImV4cCI6MjA5MTQ0ODk3MH0.mIRsPLLoHn9jQtvCCwxG3aNFWtXIdcV12kLTC_MqybY',
  {
    auth: { persistSession: false },
    db: { schema: 'public' }
  }
);

const supabaseEmpaque = supabaseCampo;
const supabaseGestion = supabaseCampo;

// ==========================================
// CONEXIÓN MYSQL (CAMPO)
// ==========================================
const poolMySQLCampo = mysql.createPool({
  host: process.env.MYSQL_HOST || 'localhost',
  user: process.env.MYSQL_USER || 'root',
  password: process.env.MYSQL_PASSWORD || '',
  database: process.env.MYSQL_DB || 'motor_bases',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

async function queryCampo(sql, params = []) {
  const [results] = await poolMySQLCampo.execute(sql, params);
  return results;
}

// ==========================================
// CONEXIÓN SQL SERVER (EMPAQUE)
// ==========================================
const sqlServerConfig = {
  user: process.env.MSSQL_USER || 'sa',
  password: process.env.MSSQL_PASSWORD || '',
  server: process.env.MSSQL_HOST || 'localhost',
  database: process.env.MSSQL_DB || 'Empaque',
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

let poolEmpaque = null;

async function getPoolEmpaque() {
  if (!poolEmpaque) {
    poolEmpaque = await mssql.connect(sqlServerConfig);
  }
  return poolEmpaque;
}

async function queryEmpaque(sqlText) {
  const pool = await getPoolEmpaque();
  const result = await pool.request().query(sqlText);
  return result.recordset;
}

async function verificarConexiones() {
  const estado = { mysql: false, supabase: false, mssql: false };
  try {
    await poolMySQLCampo.query('SELECT 1');
    estado.mysql = true;
  } catch (e) {
    console.warn('MySQL Campo fuera de línea:', e.message);
  }

  try {
    const { error } = await supabaseCampo.from('comex_usuarios').select('id').limit(1);
    if (!error) estado.supabase = true;
  } catch (e) {
    console.warn('Supabase fuera de línea:', e.message);
  }

  return estado;
}

module.exports = {
  poolMySQLCampo,
  queryCampo,
  supabaseCampo,
  supabaseEmpaque,
  getPoolEmpaque,
  queryEmpaque,
  verificarConexiones,
  supabaseGestion
};