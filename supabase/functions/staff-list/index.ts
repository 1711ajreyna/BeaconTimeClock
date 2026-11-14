import { admin, caller, response, toApp, type StaffRow } from '../_shared/staff.ts';
Deno.serve(async (req) => {
  if (req.method !== 'GET') return response({ error: 'Method not allowed' }, 405);
  try {
    const db = admin();
    const actor = await caller(req, db);
    if (actor.role !== 'hr' && actor.role !== 'supervisor')
      return response({ error: 'Forbidden' }, 403);
    let q = db.from('btc_staff_profiles').select('*')
      .in('role', ['employee', 'supervisor']).order('name', { ascending: true });
    if (actor.role === 'supervisor') q = q.eq('role', 'employee').eq('department', actor.department!);
    const { data, error } = await q;
    if (error) throw error;
    return response((data as StaffRow[]).map(toApp));
  } catch (error) {
    return response({ error: error instanceof Error ? error.message : 'Request failed' }, 401);
  }
});
