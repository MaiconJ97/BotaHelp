const assert = require('node:assert/strict');
const test = require('node:test');
const { runtime } = require('./lisp-runtime.cjs');

// Small native-call fixture for straight and circular LWPOLYLINE segments.
// The spacing, merging, DXF write and final validation run from the real LSP.
function polyline(points, bulges = [], widths = []) {
  let vertices = points.map((p, i) => [p, bulges[i] || 0, ...(widths[i] || [0, 0])]);
  let writes = 0;
  const pair = (car, cdr) => ({ pair: true, car, cdr });
  const key = p => Array.isArray(p) ? p[0] : p.car;
  const value = p => Array.isArray(p) ? p.slice(1) : p.cdr;
  function segment(i) {
    const [p, b] = vertices[i], q = vertices[i + 1][0];
    const chord = Math.hypot(q[0] - p[0], q[1] - p[1]);
    if (!b) return { length: chord, point: f => p.map((v, axis) => v + f * (q[axis] - v)) };
    const theta = 4 * Math.atan(b), r = chord * (1 + b * b) / (4 * Math.abs(b));
    const offset = chord * (1 - b * b) / (4 * b);
    const c = [(p[0] + q[0]) / 2 - (q[1] - p[1]) / chord * offset,
      (p[1] + q[1]) / 2 + (q[0] - p[0]) / chord * offset];
    const a = Math.atan2(p[1] - c[1], p[0] - c[0]);
    return { length: Math.abs(theta) * r,
      point: f => [c[0] + r * Math.cos(a + f * theta), c[1] + r * Math.sin(a + f * theta), p[2]] };
  }
  const station = i => Array.from({ length: i }, (_, k) => segment(k).length).reduce((a, b) => a + b, 0);
  function pointAt(d) {
    let a = 0;
    for (let i = 0; i < vertices.length - 1; i++) {
      const s = segment(i);
      if (d <= a + s.length + 1e-9) return s.point(Math.max(0, Math.min(1, (d - a) / s.length)));
      a += s.length;
    }
    return vertices.at(-1)[0];
  }
  const rt = runtime({
    'vlax-ename->vla-object': e => e,
    'vlax-curve-getendparam': () => vertices.length - 1,
    'vlax-curve-getdistatparam': (_, i) => station(i),
    'vlax-curve-getpointatdist': (_, d) => pointAt(d),
    'vlax-curve-getstartpoint': () => vertices[0][0],
    'vlax-curve-getendpoint': () => vertices.at(-1)[0],
    b2_curve_total_length: () => station(vertices.length - 1),
    'vla-getbulge': (_, i) => vertices[i][1],
    'vla-getwidth': (_, i, start, end) => { rt.set(start, vertices[i][2]); rt.set(end, vertices[i][3]); },
    trans: p => p,
    entget: () => [pair(0, 'LWPOLYLINE'), pair(90, vertices.length), pair(70, 0),
      pair(8, 'TestLayer'), pair(38, 0), pair(210, [0, 0, 1]), ...vertices.flatMap(v =>
        [pair(10, v[0].slice(0, 2)), pair(42, v[1]), pair(40, v[2]), pair(41, v[3])])],
    entmod: data => {
      const updated = [];
      for (const p of data) {
        const k = key(p), v = value(p);
        if (k === 10) updated.push([[v[0], v[1], 0], 0, 0, 0]);
        if ([42, 40, 41].includes(k)) updated.at(-1)[{ 42: 1, 40: 2, 41: 3 }[k]] = v;
      }
      assert.equal(value(data.find(p => key(p) === 90)), updated.length);
      assert.equal(value(data.find(p => key(p) === 8)), 'TestLayer');
      vertices = updated;
      writes++;
      return data;
    },
    entupd: () => true,
  });
  return { rt, pointAt, station, length: () => station(vertices.length - 1),
    vertices: () => structuredClone(vertices), writes: () => writes };
}

test('range subdivision balances whole runs instead of leaving a short remainder', () => {
  const rt = runtime();
  for (const [length, count] of [[0.8, 1], [1.5, 1], [1.51, null], [1.6, 2], [3.7, 3], [7.5, 5]])
    assert.equal(rt.invoke('b3_spacing_count', [length, 0.8, 1.5]), count, String(length));
  for (const length of [0.1, 0.799, 1.5001])
    assert.equal(rt.invoke('b3_spacing_count', [length, 0.8, 1.5]), null);
  for (let i = 1; i <= 500; i++) {
    const length = i * 0.037;
    const n = rt.invoke('b3_spacing_count', [length, 0.8, 1.5]);
    const feasible = Math.ceil(length / 1.5) <= Math.floor((length + 1e-6) / 0.8);
    assert.equal(n !== null, feasible, String(length));
    if (n) assert.ok(length / n >= 0.8 - 1e-6 && length / n <= 1.5 + 1e-6);
  }
});

test('close collinear vertices are redistributed without changing the path in either direction', () => {
  for (const reversed of [false, true]) {
    const points = [0, 0.2, 0.4, 1, 2.8, 3.7].map(x => [x, 0, 0]);
    const f = polyline(reversed ? points.reverse() : points);
    const total = f.length(), before = Array.from({ length: 21 }, (_, i) => f.pointAt(total * i / 20));
    assert.equal(f.rt.invoke('b3_spacing_interval', ['e', 0, total, 0.8, 1.5]), 'e');
    assert.equal(f.vertices().length, 4);
    assert.ok(Math.abs(f.length() - total) < 1e-8);
    before.forEach((p, i) => assert.ok(Math.hypot(...p.map((v, k) => v - f.pointAt(total * i / 20)[k])) < 1e-8));
    assert.equal(f.rt.invoke('b3_density_range_valid_p', ['e', 0, total, 0.8, 1.5]), true);
  }
});

test('only the maneuver window is redistributed; exterior vertices stay in place', () => {
  const f = polyline([0, 0.1, 0.4, 2, 4, 8, 9.8, 10].map(x => [x, 0, 0]));
  assert.equal(f.rt.invoke('b3_spacing_interval', ['e', 0.25, 9.75, 0.8, 1.5]), 'e');
  const xs = f.vertices().map(v => v[0][0]);
  assert.deepEqual(xs.slice(0, 3), [0, 0.1, 0.25]);
  assert.deepEqual(xs.slice(-3), [9.75, 9.8, 10]);
  assert.equal(f.rt.invoke('b3_density_range_valid_p', ['e', 0.25, 9.75, 0.8, 1.5]), true);
});

test('continuous circular arcs merge with their bulges and width ramps intact', () => {
  for (const direction of [1, -1]) {
    const r = 4, sweep = direction * 0.3;
    const points = Array.from({ length: 7 }, (_, i) => [r * Math.cos(sweep * i / 6), r * Math.sin(sweep * i / 6), 0]);
    const bulges = Array(6).fill(Math.tan(sweep / 24));
    const widths = Array.from({ length: 6 }, (_, i) => [0.2 + i * 0.1, 0.3 + i * 0.1]);
    const f = polyline(points, bulges, widths), total = f.length();
    const before = Array.from({ length: 11 }, (_, i) => f.pointAt(total * i / 10));
    assert.equal(f.rt.invoke('b3_spacing_interval', ['e', 0, total, 0.8, 1.5]), 'e');
    assert.equal(f.vertices().length, 2);
    assert.ok(Math.abs(f.vertices()[0][1] - Math.tan(sweep / 4)) < 1e-10);
    assert.ok(Math.abs(f.vertices()[0][2] - 0.2) < 1e-10);
    assert.ok(Math.abs(f.vertices()[0][3] - 0.8) < 1e-10);
    before.forEach((p, i) => assert.ok(Math.hypot(...p.map((v, k) => v - f.pointAt(total * i / 10)[k])) < 1e-8));
  }
});

test('infeasible runs keep their original vertices and report their stations', () => {
  for (const f of [
    polyline([[0, 0, 0], [1, 0, 0], [1, 0.4, 0], [2, 0.4, 0]]),
    polyline([[0, 0, 0], [1.51, 0, 0]]),
    polyline([[0, 0, 0], [0.4, 0, 0], [1.6, 0, 0]], [], [[0.2, 0.4], [0.6, 0.8]]),
  ]) {
    const before = f.vertices();
    assert.equal(f.rt.invoke('b3_spacing_interval', ['e', 0, f.length(), 0.8, 1.5]), 'e');
    assert.deepEqual(f.vertices(), before);
    const skipped = f.rt.get('*bota3_spacing_skipped*');
    assert.ok(skipped.length > 0);
    assert.ok(skipped.every(([a, b]) => a >= 0 && b > a && b <= f.length()));
    assert.equal(f.rt.invoke('b3_spacing_result_valid_p', ['e', 0, f.length(), 0.8, 1.5, skipped]), true);
  }
});

test('a skipped 1.51 m run does not prevent redistribution on both sides', () => {
  const f = polyline([[0, 0, 0], [3.7, 0, 0], [3.7, 1.51, 0], [7.4, 1.51, 0]]);
  assert.equal(f.rt.invoke('b3_spacing_interval', ['e', 0, f.length(), 0.8, 1.5]), 'e');
  assert.equal(f.vertices().length, 8);
  const skipped = f.rt.get('*bota3_spacing_skipped*');
  assert.equal(skipped.length, 1);
  assert.ok(Math.abs(skipped[0][0] - 3.7) < 1e-8);
  assert.ok(Math.abs(skipped[0][1] - 5.21) < 1e-8);
  assert.deepEqual(skipped[0].slice(2), [[3.7, 0, 0], [3.7, 1.51, 0]]);
  assert.equal(f.rt.invoke('b3_density_range_valid_p', ['e', 0, f.length(), 0.8, 1.5]), null);
  assert.equal(f.rt.invoke('b3_spacing_result_valid_p', ['e', 0, f.length(), 0.8, 1.5, skipped]), true);
  assert.equal(f.rt.invoke('b3_spacing_result_valid_p', ['e', 0, f.length(), 0.8, 1.5, []]), null);
  assert.equal(f.rt.invoke('b3_spacing_result_valid_p', ['e', 0, f.length(), 0.8, 1.5, [[0, 1]]]), null);
});

test('invalid geometry or bounds still fail and clear the previous report', () => {
  const f = polyline([[0, 0, 0], [0, 0, 0], [2, 0, 0]]);
  f.rt.set('*bota3_spacing_skipped*', [[0, 1]]);
  assert.equal(f.rt.invoke('b3_spacing_interval', ['e', 0, f.length(), 0.8, 1.5]), null);
  assert.equal(f.writes(), 0);
  assert.equal(f.rt.get('*bota3_spacing_skipped*'), null);
  assert.equal(f.rt.invoke('b3_spacing_interval', ['e', 0, f.length(), 2, 1.5]), null);
});

test('the completion report identifies skipped intervals without declaring full range compliance', () => {
  const output = [];
  const rt = runtime({ itoa: String, prompt: text => output.push(text) }, {
    '*bota3_spacing_skipped*': [[3.7, 5.21, [3.7, 0, 0], [3.7, 1.51, 0]]],
    '*bota3_densify_min*': 0.8, '*bota3_densify_seg*': 1.5,
  });
  rt.invoke('b3_spacing_report');
  assert.match(output.join(''), /1 trecho.*fora da faixa/);
  assert.match(output.join(''), /Trecho de 3.7 a 5.21 m/);
  assert.match(output.join(''), /concluida com essas excecoes/);
});

test('final validation detects undersized and oversized segments at joins', () => {
  for (const xs of [[0, 1, 1.2, 2.2], [0, 1, 2.6, 3.6]]) {
    const f = polyline(xs.map(x => [x, 0, 0]));
    assert.equal(f.rt.invoke('b3_density_range_valid_p', ['e', 0, f.length(), 0.8, 1.5]), null);
  }
});

test('BOTA3 applies the range to both margins and refuses to replace originals on failure', () => {
  let received, deleted = false;
  const rt = runtime({
    b3_validate_inputs: () => true, b3_circle_gap_directional: () => ['turn'], b3_track: e => e,
    b3_analytic_fillet: () => ['maneuver', 10], b2_copy_entity: () => 'copy',
    b2_split_copy_at_point: () => ['keep', 'other'], b3_select_opposite_pside: () => 'keep',
    b3_join_chain: () => 'result', b3_point_really_on_curve: () => true,
    b2_curve_dist_at_point: (_, p) => p, b2_curve_total_length: () => 20,
    b3_spacing_interval: (...args) => { received = args; return null; },
    entdel: () => { deleted = true; },
  }, { '*bota3_densify*': true, '*bota_trans_l*': 5,
    '*bota3_densify_min*': 0.8, '*bota3_densify_seg*': 1.5 });
  assert.equal(rt.invoke('b3_stage', ['header', 'guide', null, null, null, 10, 2, null, 70, 30, 1.5, 28]), null);
  assert.deepEqual(received, ['result', 0, 15, 0.8, 1.5]);
  assert.equal(deleted, false);
  assert.match(rt.get('*bota3_fillet_fail*'), /0.8 a 1.5.*originais foram preservados/);
});
