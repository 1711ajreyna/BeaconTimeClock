// STAGING STARTER: role-validated staff endpoints for Supabase Edge Functions.
// Do not put secret keys in iOS, do not trust user_metadata for a role,
// and do not deploy to real payroll tenants until reviewed and tested.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

const departments = new Set(['electrical', 'machine_shop', 'metals', 'plastics', 'litho']);
export type Role = 'employee' | 'supervisor' | 'hr' | 'admin';
export type StaffRow = {
  id: string; employee_id: string | null; name: string; email: string;
  employee_number: string; role: Role; department: string | null;
  is_active: boolean;
};

function envKey(newName: string, legacyName: string): string {
  const named = Deno.env.get(newName);
  if (named) {
    try { const parsed = JSON.parse(named); if (parsed.default) return parsed.default; }
    catch { /* fallback when a directly populated key is used */ }
    if (!named.trim().startsWith('{')) return named;
  }
  const legacy = Deno.env.get(legacyName);
  if (legacy) return legacy;
  throw new Error(`Supabase function secret ${newName} is missing`);
}

export function admin(): SupabaseClient {
  return createClient(Deno.env.get('SUPABASE_URL')!,
    envKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY'),
    { auth: { persistSession: false, autoRefreshToken: false } });
}

export function response(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}

export async function caller(req: Request, db: SupabaseClient): Promise<StaffRow> {
  const token = (req.headers.get('Authorization') || '').match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) throw new Error('Unauthorized');
  // getUser(token) validates JWT with Supabase Auth. Do not decode without verifying.
  const { data: userData, error: authError } = await db.auth.getUser(token);
  if (authError || !userData.user) throw new Error('Unauthorized');
  const { data, error } = await db.from('btc_staff_profiles').select('*')
    .eq('id', userData.user.id).eq('is_active', true).single();
  if (error || !data) throw new Error('Not an active staff member');
  return data as StaffRow;
}

export function mayManage(actor: StaffRow, intendedRole: string,
                          department: string | null, prior?: StaffRow): boolean {
  if (!['employee', 'supervisor'].includes(intendedRole) ||
      !department || !departments.has(department)) return false;
  if (prior && !['employee', 'supervisor'].includes(prior.role)) return false;
  if (actor.role === 'hr') return true;
  return actor.role === 'supervisor' && intendedRole === 'employee' &&
    department === actor.department &&
    (!prior || (prior.role === 'employee' && prior.department === actor.department));
}

export function toApp(row: StaffRow) {
  return { id: row.id, employeeID: row.employee_id, name: row.name,
    email: row.email, employeeNumber: row.employee_number,
    role: row.role, department: row.department, isActive: row.is_active };
}

export function normalize(body: Record<string, unknown>) {
  const name = String(body.name ?? '').trim();
  const email = String(body.email ?? '').trim().toLowerCase();
  const number = String(body.employeeNumber ?? '').trim().toUpperCase();
  const role = String(body.role ?? '');
  const department = body.department == null ? null : String(body.department);
  const isActive = body.isActive === true;
  if (name.length < 1 || name.length > 120 ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      !/^[A-Z0-9-]{1,24}$/.test(number) ||
      !['employee','supervisor'].includes(role) ||
      !department || !departments.has(department)) {
    throw new Error('Invalid name, email, employee number, role or department');
  }
  return { name, email, number, role, department, isActive };
}
