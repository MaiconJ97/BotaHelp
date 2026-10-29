const assert = require('node:assert/strict');
const test = require('node:test');
const { runtime, definitions, walk, parse } = require('./lisp-runtime.cjs');

test('densification inserts interval boundaries and bounds every interior gap', () => {
  const rt = runtime();
  for (const [d0, d1, low, high, spacing] of [
    [0, 30, 5, 25, 1], [0, 3.7, 0, 3.7, 1], [10, 10.2, 5, 25, 1],
    [0, 10, 2.25, 7.9, 0.6], [0, 5, 0, 5, 1], [0, 3, 5, 25, 1],
  ]) {
    const inserted = rt.invoke('b3_densify_stations', [d0, d1, low, high, spacing]) || [];
    const distances = [d0, ...inserted, d1];
    assert.equal(new Set(distances).size, distances.length);
    assert.ok(inserted.every(d => d > d0 && d < d1));
    if (Math.min(d1, high) > Math.max(d0, low)) {
      for (const boundary of [Math.max(d0, low), Math.min(d1, high)])
        assert.ok(distances.some(d => Math.abs(d - boundary) < 1e-8));
      for (let i = 1; i < distances.length; i++) {
        if (distances[i] > low + 1e-8 && distances[i - 1] < high - 1e-8)
          assert.ok(distances[i] - distances[i - 1] <= spacing + 1e-8);
      }
    } else assert.deepEqual(inserted, []);
  }
});

test('arc subdivision preserves total sweep for either orientation and major arcs', () => {
  const rt = runtime();
  for (const b of [0, Math.tan(Math.PI / 8), -1, 2.4, -2.4]) {
    let sweep = 0;
    for (const fraction of [0.1, 0.25, 0.35, 0.3]) {
      const sub = rt.invoke('b3_bulge_fraction', [b, fraction]);
      sweep += 4 * Math.atan(sub);
      assert.equal(Math.sign(sub), Math.sign(b));
    }
    assert.ok(Math.abs(sweep - 4 * Math.atan(b)) < 1e-12);
  }
});

test('disabled densification is an exact no-op even with incomplete settings', () => {
  const rt = runtime({}, { '*bota3_densify*': null });
  assert.equal(rt.invoke('b3_apply_densification', ['result', null, null]), 'result');
  assert.ok(!rt.calls.some(([name]) => name === 'b3_densify_interval'));
});

test('whole maneuver interval includes both margins and respects reversed orientation and short arms', () => {
  for (const [entry, exit, total, margin, expected] of [
    [20, 60, 100, 5, [15, 65]], [60, 20, 100, 5, [15, 65]],
    [2, 28, 30, 5, [0, 30]], [20, 60, 100, 0, [20, 60]],
  ]) {
    let received;
    const rt = runtime({
      b3_point_really_on_curve: () => true,
      b2_curve_dist_at_point: (_, p) => p,
      b2_curve_total_length: () => total,
      b3_densify_interval: (...args) => { received = args; return args[0]; },
    }, { '*bota3_densify*': true, '*bota_trans_l*': margin, '*bota3_densify_seg*': 0.7 });
    assert.equal(rt.invoke('b3_apply_densification', ['result', entry, exit]), 'result');
    assert.deepEqual(received, ['result', ...expected, 0.7]);
  }
});

test('densification failure prevents the transactional stage from replacing originals', () => {
  const rt = runtime({
    b3_validate_inputs: () => true,
    b3_circle_gap_directional: () => ['turn'],
    b3_track: e => e,
    b3_analytic_fillet: () => ['maneuver', 'exit'],
    b2_copy_entity: () => 'header-copy',
    b2_split_copy_at_point: () => ['keep', 'other'],
    b3_select_opposite_pside: () => 'keep',
    b3_join_chain: () => 'result',
    b3_apply_densification: () => null,
  });
  assert.equal(rt.invoke('b3_stage', [
    'header', 'guide', [1, 0, 0], [0, 1, 0], [0, 10, 0], 10,
    [0, 0, 0], [1, 0, 0], 70, 25, 1.5, 28,
  ]), null);
  assert.ok(!rt.calls.some(([name]) => name === 'entdel'));
});

test('disabled state and zero margin survive reinitialization', () => {
  const rt = runtime({}, {
    '*bota3_densify*': null, '*bota3_densify_configurado*': true,
    '*bota_trans_l*': 0, '*bota3_densify_seg*': 0.6,
  });
  rt.invoke('_bota3_init_densification');
  assert.equal(rt.get('*bota3_densify*'), null);
  assert.equal(rt.get('*bota_trans_l*'), 0);
  assert.equal(rt.get('*bota3_densify_seg*'), 0.6);
});

function configRuntime(initial = {}) {
  const files = new Map();
  const rt = runtime({
    open: (name, mode) => {
      if (mode === 'w') files.set(name, []);
      return files.has(name) ? { name, cursor: 0 } : null;
    },
    'write-line': (line, file) => files.get(file.name).push(line),
    'read-line': file => files.get(file.name)[file.cursor++] ?? null,
    close: () => null,
    strcase: s => s.toUpperCase(),
    'vl-string-trim': (_, s) => s.trim(),
    'vl-string-search': (part, s) => { const i = s.indexOf(part); return i < 0 ? null : i; },
    substr: (s, start, length) => s.slice(start - 1, length === undefined ? undefined : start - 1 + length),
    'vl-string-translate': (from, to, s) => s.replaceAll(from, to),
    distof: s => /^[+-]?(\d+(\.\d*)?|\.\d+)$/.test(s) ? Number(s) : null,
    itoa: n => String(n),
    mapcar: (fn, a) => a.map(v => rt.invoke(fn, [v])),
  }, {
    '*bota_rgiro*': 10, '*bota_impl*': 36.578, '*bota_distseg*': 0.9,
    '*bota_seguridad*': 0.2, '*bota_fillet_r*': 25, '*bota_fillet_seg*': 1.5,
    '*botaf_fillet_r*': 10, '*botaf_fillet_seg*': 1.5,
    '*botaf_auto_ranges*': [[87, 90, 10, 0.7], [90, 120, 12.5, 1], [120, 135, 15, 1.2], [135, 180, 18, 1.2]],
    '*bota_conectar_cab*': true, '*bota_cortar_circulo*': true,
    '*bota3_densify_configurado*': true, '*bota3_densify*': false,
    '*bota_trans_l*': 3.5, '*bota3_densify_seg*': 0.75, '*bota3_densify_min*': 0.4,
    ...initial,
  });
  return { rt, files };
}

test('profile roundtrip persists disabled state, margins and both spacing bounds', () => {
  const { rt } = configRuntime();
  assert.equal(rt.invoke('_bota_cfg_save_file', ['profile']), true);
  const values = rt.invoke('_bota_cfg_values_from_file', ['profile']);
  assert.deepEqual(values.slice(11), [0, 3.5, 0.75, 0.4]);
  rt.invoke('_bota_cfg_apply_values', [values]);
  rt.invoke('_bota3_init_densification');
  assert.equal(rt.get('*bota3_densify*'), false);
  assert.equal(rt.get('*bota_trans_l*'), 3.5);
  assert.equal(rt.get('*bota3_densify_seg*'), 0.75);
  assert.equal(rt.get('*bota3_densify_min*'), 0.4);
});

test('older profiles use defaults; present but invalid values reject the entire profile', () => {
  const { rt, files } = configRuntime();
  rt.invoke('_bota_cfg_save_file', ['new']);
  const old = files.get('new').filter(line => !line.startsWith('BOTA3_'));
  files.set('old', old);
  assert.deepEqual(rt.invoke('_bota_cfg_values_from_file', ['old']).slice(11), [1, 5, 1, 0]);
  files.set('previous', files.get('new').filter(line => !line.startsWith('BOTA3_DENSIFY_MIN=')));
  assert.deepEqual(rt.invoke('_bota_cfg_values_from_file', ['previous']).slice(11), [0, 3.5, 0.75, 0]);
  for (const [key, value] of [
    ['BOTA3_DENSIFY', '2'], ['BOTA3_TRANS_L', '-1'], ['BOTA3_DENSIFY_SEG', '0'],
    ['BOTA3_TRANS_L', ''], ['BOTA3_DENSIFY_SEG', 'text'],
    ['BOTA3_DENSIFY_MIN', '-0.1'], ['BOTA3_DENSIFY_MIN', '1.1'],
    ['BOTA3_DENSIFY_MIN', ''], ['BOTA3_DENSIFY_MIN', 'text'],
  ]) {
    files.set('bad', [...old, `${key}=${value}`]);
    assert.equal(rt.invoke('_bota_cfg_values_from_file', ['bad']), null, `${key}=${value}`);
    assert.equal(rt.get('*bota_trans_l*'), 3.5);
  }
});

test('DCL action includes the toggle and strict numeric validation for new fields', () => {
  const rt = runtime({ itoa: String });
  const action = rt.invoke('_bota_cfg_dcl_commit_action', [1]);
  assert.equal(parse(action).length, 1, 'complete executable action');
  for (const key of ['b3Densify', 'b3TransL', 'b3DensSeg', 'b3MinSeg']) assert.ok(action.includes(key));
  const names = [];
  walk(definitions.get('_bota_show_dcl'), node => {
    if (node[0] === 'set_tile') names.push(node[1].str);
  });
  for (const key of ['b3Densify', 'b3TransL', 'b3DensSeg', 'b3MinSeg']) assert.ok(names.includes(key));
});
