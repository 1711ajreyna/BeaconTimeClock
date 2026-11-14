import { admin, caller, response, mayManage, toApp, normalize,
         type StaffRow } from '../_shared/staff.ts';

Deno.serve(async (req) => {
  if (req.method !== 'POST') return response({ error: 'Method not allowed' }, 405);
  try {
    const db = admin();
    const actor = await caller(req, db);
    if (actor.role !== 'hr' && actor.role !== 'supervisor')
      return response({ error: 'Forbidden' }, 403);
    const body = await req.json() as Record<string, unknown>;
    const input = normalize(body);
    // The iOS client uses a temporary UUID for new staff. If no matching row
    // exists, we create an Auth user and use its actual identity as the row ID.
    let existing: StaffRow | null = null;
    if (typeof body.id === 'string') {
      const { data, error } = await db.from('btc_staff_profiles').select('*').eq('id', body.id).maybeSingle();
      if (error) throw error;
      existing = data as StaffRow | null;
    }
    if (!mayManage(actor, input.role, input.department, existing ?? undefined))
      return response({ error: 'Role or department access denied' }, 403);

    if (existing) {
      if (input.email !== existing.email || input.number !== existing.employee_number)
        return response({ error: 'Email and employee number require a separately verified change workflow' }, 422);
      // Preserve original identity/history; do not let a client choose employee_id.
      const { data, error } = await db.from('btc_staff_profiles').update({
        name: input.name, role: input.role, department: input.department,
        is_active: input.isActive,
        employee_id: existing.employee_id ?? (input.role === 'employee' ? existing.id : null),
        updated_at: new Date().toISOString(),
      }).eq('id', existing.id).select('*').single();
      if (error) throw error;
      return response(toApp(data as StaffRow));
    }

    // Invite instead of creating/distributing an insecure shared password.
    // Configure a real SMTP sender and Auth redirect URL before production.
    const { data: invited, error: inviteError } = await db.auth.admin.inviteUserByEmail(input.email);
    if (inviteError || !invited.user) throw inviteError ?? new Error('Invitation failed');
    const id = invited.user.id;
    const { data, error } = await db.from('btc_staff_profiles').insert({
      id, employee_id: input.role === 'employee' ? id : null,
      name: input.name, email: input.email, employee_number: input.number,
      role: input.role, department: input.department,
      is_active: input.isActive, created_by: actor.id,
    }).select('*').single();
    if (error) {
      // Auth invitation and profile insert are not one DB transaction.
      // Preserve the invited identity and require a secure admin reconciliation;
      // deleting a user automatically could destroy a legitimate account.
      console.error('Auth invitation exists but staff profile insert failed', id, error.code);
      return response({ error: 'Invitation created; staff profile requires administrator reconciliation' }, 500);
    }
    return response(toApp(data as StaffRow), 201);
  } catch (error) {
    return response({ error: error instanceof Error ? error.message : 'Request failed' }, 400);
  }
});
