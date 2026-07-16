'use client';

import { useEffect, useState } from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';

const API = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1';

type School = {
  id: string;
  code: string;
  name: string;
  city?: string;
  plan: string;
  status: string;
  sms_credits: number;
  max_students?: number;
  plan_expires_at?: string;
  student_count: string;
  teacher_count: string;
  last_attendance?: string;
};

type Slip = { schoolCode: string; principal: { name: string; phone: string; tempPassword: string } };

type Analytics = {
  schools: { total: string; active: string; suspended: string };
  activeStudents: number;
  usersByRole: { role: string; count: string }[];
  onlineFeeVolume: number;
  schoolsMarkedAttendanceToday: number;
  invoicesThisMonth: { total: string; paid: string };
};

export default function SuperAdmin() {
  const [token, setToken] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setToken(localStorage.getItem('sa_token'));
    setReady(true);
  }, []);

  if (!ready) return null;
  if (!token) return <Login onLogin={(t) => { localStorage.setItem('sa_token', t); setToken(t); }} />;
  return <Dashboard token={token} onLogout={() => { localStorage.removeItem('sa_token'); setToken(null); }} />;
}

function Login({ onLogin }: { onLogin: (t: string) => void }) {
  const [email, setEmail] = useState('founder@vidyatrack.in');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${API}/superadmin/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (!res.ok || !data.accessToken) throw new Error(data.message || 'Login failed');
      onLogin(data.accessToken);
    } catch (err: any) {
      setError(err.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen bg-gray-50 flex items-center justify-center p-6">
      <form onSubmit={submit} className="bg-white rounded-2xl shadow p-8 w-full max-w-sm">
        <h1 className="text-2xl font-bold text-blue-700">VidyaTrack</h1>
        <p className="text-gray-500 text-sm mb-6">Platform Super-Admin</p>
        {error && <div className="bg-red-50 text-red-600 text-sm rounded-lg p-2 mb-3">{error}</div>}
        <label className="block text-sm text-gray-600 mb-1">Email</label>
        <input value={email} onChange={(e) => setEmail(e.target.value)} className="w-full border rounded-lg px-3 py-2 mb-4" />
        <label className="block text-sm text-gray-600 mb-1">Password</label>
        <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} className="w-full border rounded-lg px-3 py-2 mb-6" />
        <button disabled={loading} className="w-full bg-blue-600 text-white rounded-lg py-2.5 font-semibold disabled:opacity-50">
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </main>
  );
}

const TABS = ['Schools', 'Analytics', 'Broadcast', 'Audit Log'] as const;
type Tab = (typeof TABS)[number];

function Dashboard({ token, onLogout }: { token: string; onLogout: () => void }) {
  const [tab, setTab] = useState<Tab>('Schools');
  const [schools, setSchools] = useState<School[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [slip, setSlip] = useState<Slip | null>(null);
  const [flagsSchool, setFlagsSchool] = useState<School | null>(null);

  const headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` };

  async function load() {
    setLoading(true);
    const res = await fetch(`${API}/superadmin/schools`, { headers });
    if (res.status === 401 || res.status === 403) return onLogout();
    setSchools(await res.json());
    setLoading(false);
  }

  useEffect(() => { load(); /* eslint-disable-next-line */ }, []);

  async function action(id: string, path: string, method = 'POST') {
    const res = await fetch(`${API}/superadmin/schools/${id}/${path}`, { method, headers });
    const data = await res.json();
    if (path === 'reset-principal' && data.principal) setSlip(data);
    load();
  }

  return (
    <main className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-3xl font-bold text-blue-700">VidyaTrack</h1>
            <p className="text-gray-500">Platform Super-Admin</p>
          </div>
          <div className="flex gap-3">
            {tab === 'Schools' && <button onClick={() => setShowCreate(true)} className="bg-blue-600 text-white rounded-lg px-4 py-2 font-semibold">+ Create School</button>}
            <button onClick={onLogout} className="text-gray-500 px-3">Logout</button>
          </div>
        </div>

        <div className="flex gap-2 mb-8 border-b">
          {TABS.map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-2 text-sm font-semibold border-b-2 -mb-px ${tab === t ? 'border-blue-600 text-blue-700' : 'border-transparent text-gray-500'}`}
            >
              {t}
            </button>
          ))}
        </div>

        {tab === 'Schools' && (
          <>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
              <Stat label="Schools" value={schools.length} color="bg-blue-100 text-blue-700" />
              <Stat label="Total Students" value={schools.reduce((s, x) => s + Number(x.student_count || 0), 0)} color="bg-green-100 text-green-700" />
              <Stat label="Total Teachers" value={schools.reduce((s, x) => s + Number(x.teacher_count || 0), 0)} color="bg-purple-100 text-purple-700" />
            </div>

            <div className="bg-white rounded-2xl shadow overflow-hidden">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 text-gray-500 text-left">
                  <tr>
                    <th className="p-3">Code</th><th className="p-3">School</th><th className="p-3">Plan</th>
                    <th className="p-3">Students</th><th className="p-3">Status</th><th className="p-3">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {loading ? (
                    <tr><td className="p-4 text-gray-400" colSpan={6}>Loading…</td></tr>
                  ) : schools.length === 0 ? (
                    <tr><td className="p-4 text-gray-400" colSpan={6}>No schools yet. Create one to get started.</td></tr>
                  ) : schools.map((s) => (
                    <tr key={s.id} className="border-t">
                      <td className="p-3 font-mono text-xs">{s.code}</td>
                      <td className="p-3 font-medium">{s.name}<div className="text-gray-400 text-xs">{s.city}</div></td>
                      <td className="p-3 capitalize">{s.plan}</td>
                      <td className="p-3">{s.student_count}</td>
                      <td className="p-3">
                        <span className={`px-2 py-0.5 rounded-full text-xs font-semibold ${s.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>{s.status}</span>
                      </td>
                      <td className="p-3">
                        <div className="flex gap-2 flex-wrap">
                          {s.status === 'active'
                            ? <button onClick={() => action(s.id, 'suspend')} className="text-red-600 text-xs">Suspend</button>
                            : <button onClick={() => action(s.id, 'activate')} className="text-green-600 text-xs">Activate</button>}
                          <button onClick={() => action(s.id, 'reset-principal')} className="text-blue-600 text-xs">Reset principal</button>
                          <button onClick={() => setFlagsSchool(s)} className="text-purple-600 text-xs">Plan & Flags</button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}

        {tab === 'Analytics' && <AnalyticsTab headers={headers} />}
        {tab === 'Broadcast' && <BroadcastTab headers={headers} schools={schools} />}
        {tab === 'Audit Log' && <AuditTab headers={headers} schools={schools} />}
      </div>

      {showCreate && <CreateModal headers={headers} onClose={() => setShowCreate(false)} onCreated={(s) => { setShowCreate(false); setSlip(s); load(); }} />}
      {slip && <SlipModal slip={slip} onClose={() => setSlip(null)} />}
      {flagsSchool && <PlanFlagsModal headers={headers} school={flagsSchool} onClose={() => setFlagsSchool(null)} onSaved={load} />}
    </main>
  );
}

function Stat({ label, value, color }: { label: string; value: number | string; color: string }) {
  return (
    <div className="bg-white rounded-2xl shadow p-6">
      <div className={`inline-block px-3 py-1 rounded-full text-sm font-semibold mb-3 ${color}`}>{label}</div>
      <div className="text-4xl font-bold text-gray-800">{value}</div>
    </div>
  );
}

function AnalyticsTab({ headers }: { headers: any }) {
  const [data, setData] = useState<Analytics | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(`${API}/superadmin/analytics`, { headers }).then((r) => r.json()).then((d) => { setData(d); setLoading(false); });
    // eslint-disable-next-line
  }, []);

  if (loading) return <div className="text-gray-400">Loading analytics…</div>;
  if (!data) return <div className="text-gray-400">No data</div>;

  const chartData = data.usersByRole.map((r) => ({ role: r.role, count: Number(r.count) }));

  return (
    <div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-8">
        <Stat label="Schools (Active/Total)" value={`${data.schools.active}/${data.schools.total}`} color="bg-blue-100 text-blue-700" />
        <Stat label="Active Students" value={data.activeStudents} color="bg-green-100 text-green-700" />
        <Stat label="Online Fee Volume" value={`₹${data.onlineFeeVolume.toLocaleString('en-IN')}`} color="bg-purple-100 text-purple-700" />
        <Stat label="Attendance Marked Today" value={data.schoolsMarkedAttendanceToday} color="bg-orange-100 text-orange-700" />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white rounded-2xl shadow p-6">
          <h3 className="font-semibold text-gray-700 mb-4">Users by Role</h3>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={chartData}>
              <XAxis dataKey="role" fontSize={12} />
              <YAxis allowDecimals={false} fontSize={12} />
              <Tooltip />
              <Bar dataKey="count" fill="#2563eb" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="bg-white rounded-2xl shadow p-6">
          <h3 className="font-semibold text-gray-700 mb-4">Invoices This Month</h3>
          <div className="text-4xl font-bold text-gray-800">{data.invoicesThisMonth.paid} <span className="text-lg text-gray-400 font-normal">/ {data.invoicesThisMonth.total} paid</span></div>
        </div>
      </div>
    </div>
  );
}

function BroadcastTab({ headers, schools }: { headers: any; schools: School[] }) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [roles, setRoles] = useState<string[]>(['admin', 'teacher', 'parent', 'student']);
  const [scope, setScope] = useState<'all' | string>('all');
  const [result, setResult] = useState<{ schoolsTargeted: number; usersNotified: number } | null>(null);
  const [sending, setSending] = useState(false);

  const toggleRole = (r: string) => setRoles((prev) => (prev.includes(r) ? prev.filter((x) => x !== r) : [...prev, r]));

  async function send(e: React.FormEvent) {
    e.preventDefault();
    setSending(true);
    setResult(null);
    const res = await fetch(`${API}/superadmin/broadcast`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ title, body, roles, schoolIds: scope === 'all' ? undefined : [scope] }),
    });
    setResult(await res.json());
    setSending(false);
  }

  return (
    <form onSubmit={send} className="bg-white rounded-2xl shadow p-6 max-w-xl">
      <h2 className="text-xl font-bold mb-4">Broadcast a Notice</h2>
      <label className="block text-sm text-gray-600 mb-1">Title</label>
      <input value={title} onChange={(e) => setTitle(e.target.value)} required className="w-full border rounded-lg px-3 py-2 mb-4" />
      <label className="block text-sm text-gray-600 mb-1">Message</label>
      <textarea value={body} onChange={(e) => setBody(e.target.value)} required rows={3} className="w-full border rounded-lg px-3 py-2 mb-4" />
      <label className="block text-sm text-gray-600 mb-1">Roles</label>
      <div className="flex gap-3 mb-4 flex-wrap">
        {['admin', 'teacher', 'parent', 'student'].map((r) => (
          <label key={r} className="flex items-center gap-1.5 text-sm capitalize">
            <input type="checkbox" checked={roles.includes(r)} onChange={() => toggleRole(r)} /> {r}
          </label>
        ))}
      </div>
      <label className="block text-sm text-gray-600 mb-1">Schools</label>
      <select value={scope} onChange={(e) => setScope(e.target.value)} className="w-full border rounded-lg px-3 py-2 mb-6">
        <option value="all">All active schools</option>
        {schools.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
      </select>
      <button disabled={sending || !roles.length} className="bg-blue-600 text-white rounded-lg px-4 py-2.5 font-semibold disabled:opacity-50">
        {sending ? 'Sending…' : 'Send Broadcast'}
      </button>
      {result && (
        <div className="mt-4 bg-green-50 text-green-700 text-sm rounded-lg p-3">
          Sent to {result.usersNotified} users across {result.schoolsTargeted} school{result.schoolsTargeted === 1 ? '' : 's'}.
        </div>
      )}
    </form>
  );
}

function AuditTab({ headers, schools }: { headers: any; schools: School[] }) {
  const [schoolId, setSchoolId] = useState('');
  const [logs, setLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
    const qs = schoolId ? `?schoolId=${schoolId}&limit=50` : '?limit=50';
    const res = await fetch(`${API}/superadmin/audit${qs}`, { headers });
    setLogs(await res.json());
    setLoading(false);
  }

  useEffect(() => { load(); /* eslint-disable-next-line */ }, [schoolId]);

  return (
    <div>
      <select value={schoolId} onChange={(e) => setSchoolId(e.target.value)} className="border rounded-lg px-3 py-2 mb-4">
        <option value="">All schools</option>
        {schools.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
      </select>
      <div className="bg-white rounded-2xl shadow overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-left">
            <tr><th className="p-3">Time</th><th className="p-3">School</th><th className="p-3">User</th><th className="p-3">Action</th></tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td className="p-4 text-gray-400" colSpan={4}>Loading…</td></tr>
            ) : logs.length === 0 ? (
              <tr><td className="p-4 text-gray-400" colSpan={4}>No audit entries</td></tr>
            ) : logs.map((l) => (
              <tr key={l.id} className="border-t">
                <td className="p-3 text-xs text-gray-500">{new Date(l.created_at).toLocaleString()}</td>
                <td className="p-3 font-mono text-xs">{l.school_code}</td>
                <td className="p-3">{l.user_name || '—'}</td>
                <td className="p-3 font-mono text-xs">{l.action}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function PlanFlagsModal({ headers, school, onClose, onSaved }: { headers: any; school: School; onClose: () => void; onSaved: () => void }) {
  const [plan, setPlan] = useState(school.plan);
  const [maxStudents, setMaxStudents] = useState(school.max_students ?? 500);
  const [settings, setSettings] = useState<{ key: string; value: string }[]>([]);
  const [newKey, setNewKey] = useState('online_payments');
  const [newValue, setNewValue] = useState('true');
  const [saving, setSaving] = useState(false);

  async function loadSettings() {
    const res = await fetch(`${API}/superadmin/schools/${school.id}/settings`, { headers });
    setSettings(await res.json());
  }
  useEffect(() => { loadSettings(); /* eslint-disable-next-line */ }, []);

  async function saveLimits() {
    setSaving(true);
    await fetch(`${API}/superadmin/schools/${school.id}/limits`, {
      method: 'PATCH', headers, body: JSON.stringify({ plan, maxStudents: Number(maxStudents) }),
    });
    setSaving(false);
    onSaved();
  }

  async function addFlag(e: React.FormEvent) {
    e.preventDefault();
    await fetch(`${API}/superadmin/schools/${school.id}/settings`, {
      method: 'PATCH', headers, body: JSON.stringify({ key: newKey, value: newValue }),
    });
    loadSettings();
  }

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-md">
        <h2 className="text-xl font-bold mb-1">{school.name}</h2>
        <p className="text-gray-400 text-xs mb-4">Plan, limits & feature flags</p>

        <label className="block text-sm text-gray-600 mb-1">Plan</label>
        <select value={plan} onChange={(e) => setPlan(e.target.value)} className="w-full border rounded-lg px-3 py-2 mb-3">
          {['trial', 'starter', 'growth', 'enterprise'].map((p) => <option key={p} value={p}>{p}</option>)}
        </select>
        <label className="block text-sm text-gray-600 mb-1">Max Students</label>
        <input type="number" value={maxStudents} onChange={(e) => setMaxStudents(Number(e.target.value))} className="w-full border rounded-lg px-3 py-2 mb-3" />
        <button onClick={saveLimits} disabled={saving} className="w-full bg-blue-600 text-white rounded-lg py-2 font-semibold mb-6 disabled:opacity-50">
          {saving ? 'Saving…' : 'Save Plan & Limits'}
        </button>

        <h3 className="font-semibold text-gray-700 mb-2 text-sm">Feature Flags</h3>
        <div className="space-y-1 mb-3">
          {settings.length === 0 ? <p className="text-gray-400 text-xs">No flags set</p> : settings.map((s) => (
            <div key={s.key} className="flex justify-between text-xs bg-gray-50 rounded-lg px-3 py-2">
              <span className="font-mono">{s.key}</span><span className="font-semibold">{s.value}</span>
            </div>
          ))}
        </div>
        <form onSubmit={addFlag} className="flex gap-2 mb-4">
          <input value={newKey} onChange={(e) => setNewKey(e.target.value)} placeholder="key" className="flex-1 border rounded-lg px-2 py-1.5 text-sm" />
          <input value={newValue} onChange={(e) => setNewValue(e.target.value)} placeholder="value" className="flex-1 border rounded-lg px-2 py-1.5 text-sm" />
          <button className="bg-gray-800 text-white rounded-lg px-3 text-sm">Set</button>
        </form>

        <button onClick={onClose} className="w-full border rounded-lg py-2">Close</button>
      </div>
    </div>
  );
}

function CreateModal({ headers, onClose, onCreated }: { headers: any; onClose: () => void; onCreated: (s: Slip) => void }) {
  const [form, setForm] = useState({ name: '', principalName: '', phone: '', email: '', city: '', maxStudents: 500 });
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const res = await fetch(`${API}/superadmin/schools`, { method: 'POST', headers, body: JSON.stringify(form) });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || 'Failed');
      onCreated(data);
    } catch (err: any) {
      setError(err.message);
      setSaving(false);
    }
  }

  const field = (key: keyof typeof form, label: string, required = false) => (
    <div className="mb-3">
      <label className="block text-sm text-gray-600 mb-1">{label}{required && ' *'}</label>
      <input value={form[key] as any} onChange={(e) => setForm({ ...form, [key]: e.target.value })} className="w-full border rounded-lg px-3 py-2" />
    </div>
  );

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4">
      <form onSubmit={submit} className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-md">
        <h2 className="text-xl font-bold mb-4">Create School</h2>
        {error && <div className="bg-red-50 text-red-600 text-sm rounded-lg p-2 mb-3">{error}</div>}
        {field('name', 'School name', true)}
        {field('principalName', 'Principal name', true)}
        {field('phone', 'Principal phone', true)}
        {field('email', 'Email')}
        {field('city', 'City')}
        <div className="flex gap-3 mt-5">
          <button type="button" onClick={onClose} className="flex-1 border rounded-lg py-2">Cancel</button>
          <button disabled={saving} className="flex-1 bg-blue-600 text-white rounded-lg py-2 font-semibold disabled:opacity-50">{saving ? 'Creating…' : 'Create'}</button>
        </div>
      </form>
    </div>
  );
}

function SlipModal({ slip, onClose }: { slip: Slip; onClose: () => void }) {
  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-sm">
        <h2 className="text-xl font-bold mb-1">Principal credentials</h2>
        <p className="text-red-600 text-xs mb-4">Shown once — copy and share securely.</p>
        <div className="bg-gray-50 rounded-lg p-4 text-sm space-y-1 font-mono">
          <div>School Code: <b>{slip.schoolCode}</b></div>
          <div>Name: {slip.principal.name}</div>
          <div>Phone (login): <b>{slip.principal.phone}</b></div>
          <div>Password: <b>{slip.principal.tempPassword}</b></div>
        </div>
        <button onClick={onClose} className="w-full bg-blue-600 text-white rounded-lg py-2.5 font-semibold mt-5">Done</button>
      </div>
    </div>
  );
}
