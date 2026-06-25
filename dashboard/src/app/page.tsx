'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

let _supabase: SupabaseClient | null = null;
function getSupabase() {
  if (!_supabase) {
    _supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
  }
  return _supabase;
}

interface Transaction {
  celular: string;
  ref_factura: string | null;
  puntos: number;
  estado: string;
  timestamp: string;
}

interface Metrics {
  total: number;
  completadas: number;
  duplicadas: number;
  errores: number;
  puntosOtorgados: number;
  csatPromedio: number | null;
  tasaExito: number | null;
  tasaDuplicados: number | null;
  recentTransactions: Transaction[];
}

function SkeletonCard() {
  return (
    <div className="animate-pulse rounded-xl p-6" style={{ backgroundColor: '#141414', border: '1px solid #1f1f1f' }}>
      <div className="h-3 w-20 rounded mb-4" style={{ backgroundColor: '#2a2a2a' }}></div>
      <div className="h-8 w-24 rounded" style={{ backgroundColor: '#2a2a2a' }}></div>
    </div>
  );
}

function MetricCard({
  label,
  value,
  accent,
  sub,
}: {
  label: string;
  value: string | number;
  accent?: string;
  sub?: string;
}) {
  return (
    <div className="rounded-xl p-6 flex flex-col gap-2" style={{ backgroundColor: '#141414', border: '1px solid #1f1f1f' }}>
      <span className="text-xs uppercase tracking-wider" style={{ color: '#a1a1aa' }}>{label}</span>
      <span className="text-3xl font-bold" style={{ color: accent || 'white' }}>{value}</span>
      {sub && <span className="text-xs" style={{ color: '#a1a1aa' }}>{sub}</span>}
    </div>
  );
}

function estadoBadge(estado: string) {
  const map: Record<string, { bg: string; text: string }> = {
    completada: { bg: 'rgba(21,128,61,0.3)', text: '#4ade80' },
    duplicada: { bg: 'rgba(146,64,14,0.3)', text: '#fbbf24' },
    error: { bg: 'rgba(153,27,27,0.3)', text: '#f87171' },
    pendiente: { bg: 'rgba(63,63,70,0.3)', text: '#a1a1aa' },
    procesando: { bg: 'rgba(63,63,70,0.3)', text: '#a1a1aa' },
  };
  const style = map[estado] || { bg: 'rgba(63,63,70,0.3)', text: '#a1a1aa' };
  return (
    <span
      className="px-2 py-1 rounded text-xs font-medium"
      style={{ backgroundColor: style.bg, color: style.text }}
    >
      {estado}
    </span>
  );
}

export default function Dashboard() {
  const [metrics, setMetrics] = useState<Metrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const fetchMetrics = useCallback(async () => {
    try {
      const [
        { count: total },
        { count: completadas },
        { count: duplicadas },
        { count: errores },
        { count: ilegibles },
        puntosRes,
        csatRes,
        transRes,
      ] = await Promise.all([
        getSupabase().from('transactions').select('*', { count: 'exact', head: true }),
        getSupabase().from('transactions').select('*', { count: 'exact', head: true }).eq('estado', 'completada'),
        getSupabase().from('transactions').select('*', { count: 'exact', head: true }).eq('estado', 'duplicada'),
        getSupabase().from('transactions').select('*', { count: 'exact', head: true }).eq('estado', 'error'),
        getSupabase().from('transactions').select('*', { count: 'exact', head: true }).eq('error_type', 'factura_ilegible'),
        getSupabase().from('transactions').select('puntos').eq('estado', 'completada'),
        getSupabase().from('transactions').select('csat').not('csat', 'is', null),
        getSupabase().from('transactions').select('celular, ref_factura, puntos, estado, timestamp').order('timestamp', { ascending: false }).limit(10),
      ]);

      const puntosOtorgados = (puntosRes.data || []).reduce((sum: number, r: { puntos: number }) => sum + (r.puntos || 0), 0);
      const csatValues = (csatRes.data || []).map((r: { csat: number }) => r.csat).filter(Boolean);
      const csatPromedio = csatValues.length > 0 ? csatValues.reduce((a: number, b: number) => a + b, 0) / csatValues.length : null;

      const c = completadas || 0;
      const il = ilegibles || 0;
      const tasaExito = (c + il) > 0 ? (c / (c + il)) * 100 : null;
      const t = total || 0;
      const d = duplicadas || 0;
      const tasaDuplicados = t > 0 ? (d / t) * 100 : null;

      setMetrics({
        total: t,
        completadas: c,
        duplicadas: d,
        errores: errores || 0,
        puntosOtorgados,
        csatPromedio,
        tasaExito,
        tasaDuplicados,
        recentTransactions: (transRes.data || []) as Transaction[],
      });
      setLastUpdated(new Date());
    } catch (e) {
      console.error('Error fetching metrics:', e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchMetrics();
    const interval = setInterval(fetchMetrics, 30000);
    return () => clearInterval(interval);
  }, [fetchMetrics]);

  return (
    <main className="min-h-screen p-6 md:p-10" style={{ backgroundColor: '#0f0f0f' }}>
      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">SuperLikers Dashboard</h1>
          <p className="text-sm mt-1" style={{ color: '#a1a1aa' }}>Métricas en tiempo real</p>
        </div>
        {lastUpdated && (
          <span className="text-xs" style={{ color: '#a1a1aa' }}>
            Actualizado: {lastUpdated.toLocaleTimeString('es-CO')}
          </span>
        )}
      </div>

      {/* Summary Cards */}
      {loading ? (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          {Array.from({ length: 4 }).map((_, i) => <SkeletonCard key={i} />)}
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <MetricCard label="Total Transacciones" value={metrics!.total.toLocaleString()} />
          <MetricCard label="Completadas" value={metrics!.completadas.toLocaleString()} accent="#22c55e" />
          <MetricCard label="Duplicadas" value={metrics!.duplicadas.toLocaleString()} accent="#f59e0b" />
          <MetricCard label="Errores" value={metrics!.errores.toLocaleString()} accent="#ef4444" />
        </div>
      )}

      {/* Secondary Metrics */}
      {loading ? (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          {Array.from({ length: 4 }).map((_, i) => <SkeletonCard key={i} />)}
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <MetricCard
            label="Puntos Otorgados"
            value={metrics!.puntosOtorgados.toLocaleString()}
            accent="#22c55e"
            sub="solo completadas"
          />
          <MetricCard
            label="CSAT Promedio"
            value={metrics!.csatPromedio !== null ? `${metrics!.csatPromedio.toFixed(1)} / 5` : 'N/A'}
            accent="#22c55e"
          />
          <MetricCard
            label="Tasa Éxito Lectura"
            value={metrics!.tasaExito !== null ? `${metrics!.tasaExito.toFixed(1)}%` : 'N/A'}
            accent="#22c55e"
            sub="completadas / (completadas + ilegibles)"
          />
          <MetricCard
            label="Tasa Duplicados"
            value={metrics!.tasaDuplicados !== null ? `${metrics!.tasaDuplicados.toFixed(1)}%` : 'N/A'}
            accent="#f59e0b"
            sub="duplicadas / total"
          />
        </div>
      )}

      {/* Retention Rate */}
      <div className="mb-8">
        <div className="rounded-xl p-6" style={{ backgroundColor: '#141414', border: '1px solid #1f1f1f' }}>
          <span className="text-xs uppercase tracking-wider" style={{ color: '#a1a1aa' }}>Retention Rate</span>
          <p className="mt-2 text-sm" style={{ color: '#a1a1aa' }}>Disponible con datos longitudinales</p>
        </div>
      </div>

      {/* Recent Transactions Table */}
      <div className="rounded-xl overflow-hidden" style={{ backgroundColor: '#141414', border: '1px solid #1f1f1f' }}>
        <div className="p-4 border-b" style={{ borderColor: '#1f1f1f' }}>
          <h2 className="text-sm font-semibold text-white uppercase tracking-wider">Últimas 10 Transacciones</h2>
        </div>
        {loading ? (
          <div className="p-6 animate-pulse space-y-3">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="h-8 rounded" style={{ backgroundColor: '#2a2a2a' }}></div>
            ))}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr style={{ borderBottom: '1px solid #1f1f1f' }}>
                  {['Celular', 'Ref. Factura', 'Puntos', 'Estado', 'Timestamp'].map(h => (
                    <th key={h} className="text-left px-4 py-3 text-xs uppercase tracking-wider" style={{ color: '#a1a1aa' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {metrics!.recentTransactions.map((tx, i) => (
                  <tr
                    key={i}
                    style={{ backgroundColor: i % 2 === 0 ? '#141414' : '#0f0f0f', borderBottom: '1px solid #1a1a1a' }}
                  >
                    <td className="px-4 py-3 font-mono text-xs" style={{ color: '#e4e4e7' }}>{tx.celular}</td>
                    <td className="px-4 py-3 font-mono text-xs" style={{ color: '#a1a1aa' }}>{tx.ref_factura || '—'}</td>
                    <td className="px-4 py-3 font-bold" style={{ color: '#22c55e' }}>{tx.puntos}</td>
                    <td className="px-4 py-3">{estadoBadge(tx.estado)}</td>
                    <td className="px-4 py-3 text-xs" style={{ color: '#a1a1aa' }}>
                      {tx.timestamp ? new Date(tx.timestamp).toLocaleString('es-CO') : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </main>
  );
}
