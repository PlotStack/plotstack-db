import pg from 'pg';

const { Pool } = pg;

let pool: pg.Pool | null = null;

export interface DbConfig {
  connectionString?: string;
  host?: string;
  port?: number;
  database?: string;
  user?: string;
  password?: string;
  max?: number;
}

/**
 * Get or create the shared connection pool.
 */
export function getPool(config?: DbConfig): pg.Pool {
  if (!pool) {
    pool = new Pool({
      connectionString: config?.connectionString || process.env.DATABASE_URL,
      host: config?.host,
      port: config?.port,
      database: config?.database,
      user: config?.user,
      password: config?.password,
      max: config?.max ?? 20,
    });
  }
  return pool;
}

/**
 * Execute a query with the shared pool.
 */
export async function query<T extends pg.QueryResultRow = pg.QueryResultRow>(
  text: string,
  params?: unknown[],
): Promise<pg.QueryResult<T>> {
  return getPool().query<T>(text, params);
}

/**
 * Get a client from the pool with tenant context set for RLS.
 */
export async function getClientWithTenant(tenantId: string): Promise<pg.PoolClient> {
  const client = await getPool().connect();
  await client.query(`SET app.current_tenant_id = '${tenantId}'`);
  return client;
}

/**
 * Run a function within a transaction scoped to a tenant.
 */
export async function withTransaction<T>(
  tenantId: string,
  fn: (client: pg.PoolClient) => Promise<T>,
): Promise<T> {
  const client = await getClientWithTenant(tenantId);
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Close the connection pool.
 */
export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}

export { pg };
