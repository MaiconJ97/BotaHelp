// Source-level regressions with simulated CAD calls, not a Civil 3D emulator.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../bota_help_v5_pt.lsp'), 'utf8');
function parse(text) {
  const tokens = text.match(/;[^\r\n]*|"(?:\\.|[^"\\])*"|'|[()]|[^\s()'";]+/g)
    .filter(token => !token.startsWith(';'));
  let i = 0;
  function read() {
    const token = tokens[i++];
    if (token === '(') {
      const list = [];
      while (tokens[i] !== ')') {
        if (i >= tokens.length) throw Error('Unclosed list');
        list.push(read());
      }
      i++;
      return list;
    }
    if (token === ')' || token === undefined) throw Error('Unexpected closing token');
    if (token === "'") return ['quote', read()];
    if (token.startsWith('"')) return { str: token.slice(1, -1).replace(/\\(.)/g, '$1') };
    if (/^[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?$/i.test(token)) return Number(token);
    return token.toLowerCase();
  }
  const forms = [];
  while (i < tokens.length) forms.push(read());
  return forms;
}
const forms = parse(source);
const definitions = new Map();
function walk(form, callback) {
  if (!Array.isArray(form)) return;
  callback(form);
  for (const child of form) walk(child, callback);
}
for (const form of forms) walk(form, node => {
  if (node[0] === 'defun') definitions.set(node[1], node);
});
const truth = value => value !== null && value !== false && value !== undefined &&
  !(Array.isArray(value) && value.length === 0);
const nil = value => truth(value) ? value : null;

function runtime(overrides = {}, globals = {}) {
  const scopes = [new Map(Object.entries(globals))];
  const calls = [];
  function get(name) {
    for (const scope of scopes) if (scope.has(name)) return scope.get(name);
    if (name === 't') return true;
    if (name === 'pi') return Math.PI;
    return null;
  }
  function set(name, value) {
    const scope = scopes.find(scope => scope.has(name)) || scopes[scopes.length - 1];
    scope.set(name, value);
    return value;
  }
  function sequence(body) {
    let result = null;
    for (const node of body) result = evaluate(node);
    return result;
  }
  const builtins = {
    list: (...items) => nil(items),
    cons: (a, b) => [a, ...(b || [])],
    car: a => a?.[0] ?? null,
    cdr: a => nil(a?.slice(1)),
    cadr: a => a?.[1] ?? null,
    caddr: a => a?.[2] ?? null,
    cadddr: a => a?.[3] ?? null,
    nth: (i, a) => a?.[i] ?? null,
    append: (...items) => nil(items.flatMap(item => item || [])),
    reverse: a => nil([...(a || [])].reverse()),
    length: a => (a || []).length,
    member: (a, list) => list?.includes(a) ? list.slice(list.indexOf(a)) : null,
    not: a => !truth(a),
    '=': (a, b) => a === b,
    '/=': (a, b) => a !== b,
    equal: (a, b, tolerance = 0) => Array.isArray(a) && Array.isArray(b)
      ? a.length === b.length && a.every((v, i) => Math.abs(v - b[i]) <= tolerance)
      : typeof a === 'number' ? Math.abs(a - b) <= tolerance : a === b,
    '+': (...a) => a.reduce((x, y) => x + y, 0),
    '-': (a, ...b) => b.length ? b.reduce((x, y) => x - y, a) : -a,
    '*': (...a) => a.reduce((x, y) => x * y, 1),
    '/': (a, b) => a / b,
    '1+': a => a + 1,
    '1-': a => a - 1,
    '<': (a, b) => a < b,
    '<=': (a, b) => a <= b,
    '>': (a, b) => a > b,
    '>=': (a, b) => a >= b,
    abs: Math.abs,
    sqrt: Math.sqrt,
    min: Math.min,
    max: Math.max,
    distance: (a, b) => Math.hypot(...a.map((value, i) => value - b[i])),
    strcat: (...parts) => parts.join(''),
    rtos: value => String(value),
    prompt: () => null,
    princ: () => null,
    'vl-catch-all-error-p': value => value instanceof Error,
    'vl-catch-all-apply': (fn, args) => {
      try { return invoke(fn, args || []); } catch (error) { return error; }
    },
    ...overrides,
  };
  function invoke(name, args = []) {
    calls.push([name, args]);
    if (builtins[name]) return builtins[name](...args);
    const def = definitions.get(name);
    if (!def) throw Error(`Unmocked function: ${name}`);
    const slash = def[2].indexOf('/');
    const params = slash < 0 ? def[2] : def[2].slice(0, slash);
    assert.equal(args.length, params.length, `${name}: argument count`);
    const frame = new Map(def[2].filter(name => name !== '/').map(name => [name, null]));
    params.forEach((name, i) => frame.set(name, args[i]));
    scopes.unshift(frame);
    try { return sequence(def.slice(3)); } finally { scopes.shift(); }
  }
  function evaluate(node) {
    if (typeof node === 'number') return node;
    if (typeof node === 'string') return get(node);
    if (node && !Array.isArray(node)) return node.str;
    if (!node?.length) return null;
    const [op, ...args] = node;
    if (op === 'quote') return args[0];
    if (op === 'progn') return sequence(args);
    if (op === 'if') return evaluate(truth(evaluate(args[0])) ? args[1] : args[2]);
    if (op === 'setq') {
      let result;
      for (let i = 0; i < args.length; i += 2) result = set(args[i], evaluate(args[i + 1]));
      return result;
    }
    if (op === 'and') return args.every(arg => truth(evaluate(arg)));
    if (op === 'or') return args.some(arg => truth(evaluate(arg)));
    if (op === 'foreach') {
      let result = null;
      for (const value of evaluate(args[1]) || []) {
        set(args[0], value);
        result = sequence(args.slice(2));
      }
      return result;
    }
    return invoke(op, args.map(evaluate));
  }
  return { invoke, get, set, calls };
}

test('BOTA2 helpers, command and debug have valid structure and call arities', () => {
  for (const name of ['_bota2_define_helpers', 'c:bota2', 'c:bota2debug']) {
    assert.ok(forms.some(form => form[0] === 'defun' && form[1] === name), `${name} is top-level`);
    walk(definitions.get(name), node => {
      if (node[0] === 'if') assert.ok(node.length === 3 || node.length === 4, 'IF arity');
      if (node[0] === 'setq') {
        assert.equal(node.length % 2, 1, 'SETQ pairs');
        for (let i = 1; i < node.length; i += 2) assert.notEqual(node[i], 't');
      }
      if (node[0] === 'defun') assert.ok(!node[2].includes('t'), 'T is not a variable');
      if (typeof node[0] === 'string' && node[0].startsWith('b2_')) {
        const def = definitions.get(node[0]);
        assert.ok(def, `Missing helper ${node[0]}`);
        const slash = def[2].indexOf('/');
        assert.equal(node.length - 1, slash < 0 ? def[2].length : slash, node[0]);
      }
      assert.notEqual(node[0], 't', 'No callable T in BOTA2');
    });
  }
});

test('centre rejects the only available offset when it is on the opposite side', () => {
  const deleted = [];
  const rt = runtime({
    b2_offset_candidates_signed: () => [['wrong', -1]],
    entget: e => e,
    b2_offset_side_score: () => -100,
    b2_dist_to_ent: () => 1,
    b2_delete_ent: e => deleted.push(e),
  });
  assert.equal(rt.invoke('b2_offset_select_toward', ['header', 10, [1, 2, 0]]), null);
  assert.deepEqual(deleted, ['wrong']);
});

test('centre keeps the requested side even if the opposite candidate is closer', () => {
  const rt = runtime({
    b2_offset_candidates_signed: () => [['wrong', -1], ['right', 1]],
    entget: e => e,
    b2_offset_side_score: (_, e) => e === 'right' ? 10 : -10,
    b2_dist_to_ent: e => e === 'right' ? 50 : 1,
    b2_delete_ent: () => null,
  });
  assert.equal(rt.invoke('b2_offset_select_toward', ['header', 10, [1, 2, 0]]), 'right');
});

test('a returning curve retains the interval containing the pick, regardless of initial direction', () => {
  for (const refDist of [3, 18]) {
    const removed = [];
    const rt = runtime({
      b2_curve_dist_at_point: (_, p) => p === 'cut' ? 10 : refDist,
      b2_curve_total_length: () => 25,
      b2_point_on_curve_p: () => true,
      'vlax-curve-getstartpoint': () => 'start',
      'vlax-curve-getendpoint': () => 'end',
      b2_split_copy_at_point: () => ['suffix', 'prefix'],
      b2_piece_matches_p: (e, end, _, len) =>
        e === (end === 'start' ? 'prefix' : 'suffix') && len === (end === 'start' ? 10 : 15),
      b2_delete_ent: e => removed.push(e),
    });
    const expected = refDist < 10 ? 'prefix' : 'suffix';
    assert.equal(rt.invoke('b2_break_copy_keep_toward', ['copy', 'cut', 'pick']), expected);
    assert.deepEqual(removed, [expected === 'prefix' ? 'suffix' : 'prefix']);
    assert.ok(!rt.calls.some(([name]) => name === 'b2_select_side_segment'));
  }
});

test('invalid cut measurement fails instead of silently using the complete curve', () => {
  const removed = [];
  const rt = runtime({
    b2_curve_dist_at_point: () => null,
    b2_curve_total_length: () => 20,
    b2_delete_ent: e => removed.push(e),
  });
  assert.equal(rt.invoke('b2_break_copy_keep_toward', ['copy', 'cut', 'pick']), null);
  assert.deepEqual(removed, ['copy']);
});

test('a semicircle does not intersect a short guide crossing only its chord', () => {
  const endpoints = { arc: [[-10, 0, 0], [10, 0, 0]], guide: [[0, -1, 0], [0, 1, 0]] };
  const rt = runtime({
    b2_intersections: () => null,
    'vlax-curve-getstartpoint': e => endpoints[e][0],
    'vlax-curve-getendpoint': e => endpoints[e][1],
    b2_closest_point: (e, p) => e === 'guide' ? [0, 0, 0] : [0, 10, 0],
  });
  assert.equal(rt.invoke('b2_intersection_best', ['arc', 'guide', [0, 0, 0]]), null);
  assert.equal(rt.calls.filter(([name]) => name === 'b2_closest_point').length, 4);
  assert.ok(!definitions.has('b2_curve_segments'));
});

test('native arc intersections are accepted, and false native points are rejected', () => {
  for (const valid of [true, false]) {
    const rt = runtime({
      b2_intersections: () => [[0, 10, 0]],
      b2_point_on_curve_p: () => valid,
      b2_endpoint_contacts: () => null,
    });
    assert.deepEqual(rt.invoke('b2_intersection_best', ['arc', 'guide', [0, 0, 0]]),
      valid ? [0, 10, 0] : null);
  }
});

test('endpoint contact omitted by IntersectWith is still recognized', () => {
  const rt = runtime({
    b2_intersections: () => null,
    'vlax-curve-getstartpoint': () => [0, 0, 0],
    'vlax-curve-getendpoint': e => e === 'a' ? [10, 0, 0] : [0, 10, 0],
    b2_closest_point: () => [0, 0, 0],
  });
  assert.deepEqual(rt.invoke('b2_intersection_best', ['a', 'b', [1, 1, 0]]), [0, 0, 0]);
});

test('virtual intersections are attempted last and retain the one metre limit', () => {
  for (const real of [true, false]) for (const extension of [0.9, 1.001]) {
    const rt = runtime({
      b2_intersection_best: () => real ? [1, 0, 0] : null,
      b2_intersection_extended_best: () => [2, 0, 0],
      b2_dist_to_ent: () => extension,
    });
    const result = rt.invoke('b2_find_offset_intersection', ['cab', [['guide', 1]], [0, 0, 0], true]);
    assert.equal(truth(result), real || extension <= 1);
    assert.equal(rt.calls.some(([name]) => name === 'b2_intersection_extended_best'), !real);
  }
});

test('command and debug call the same preparation helper; centre uses the guide pick', () => {
  for (const name of ['b2_run_simple', 'c:bota2debug']) {
    let count = 0;
    walk(definitions.get(name), node => { if (node[0] === 'b2_prepare_offsets') count++; });
    assert.equal(count, 1);
  }
  walk(definitions.get('b2_run_simple'), node => {
    if (node[0] === 'b2_offset_select_toward') assert.equal(node[3], 'pguiapick');
  });
  assert.ok(!definitions.has('_bota2d_offset_all'));
});

test('failed split, creation, join or commit preserves the original and removes staged objects', () => {
  for (const failure of ['split', 'giro', 'join', 'outer', 'erase', null]) {
    const live = new Set(['original']);
    const deletedOriginal = [];
    const make = e => { live.add(e); return e; };
    let rt;
    rt = runtime({
      entget: e => live.has(e) ? e : null,
      entdel: e => {
        if (failure === 'erase') return null;
        deletedOriginal.push(e);
        if (live.has(e)) live.delete(e); else live.add(e);
        return e;
      },
      b2_copy_entity: () => rt.invoke('b2_track_temp', [make('copy')]),
      b2_split_copy_at_point: () => failure === 'split' ? null :
        ['copy', rt.invoke('b2_track_temp', [make('other')])],
      b2_circle_gap_directional: () => failure === 'giro' ? null : [make('giro')],
      b2_select_side_segment: () => 'copy',
      b2_join_two: () => {
        if (failure === 'join') return null;
        live.delete('copy');
        return true;
      },
      b2_circle_entity: () => failure === 'outer' ? null : make('outer'),
      b2_delete_ent: e => live.delete(e),
    }, { ent: 'original', '*bota_cortar_circulo*': true, '*bota_conectar_cab*': true });
    assert.equal(truth(rt.invoke('b2_commit_maneuver')), failure === null, failure);
    assert.deepEqual([...live].sort(), failure ? ['original'] : ['giro', 'other', 'outer']);
    assert.deepEqual(deletedOriginal, failure ? [] : ['original']);
  }
});

test('error cleanup restores an original erased before commit and removes nested temporaries', () => {
  const live = new Set(['copy', 'offset']);
  const rt = runtime({
    entget: e => live.has(e) ? e : null,
    entdel: e => { live.add(e); return e; },
    b2_delete_ent: e => live.delete(e),
  }, { b2original: 'original', b2temps: ['offset', 'copy'], b2committed: null });
  rt.invoke('b2_clear_temporaries');
  assert.deepEqual([...live], ['original']);
});

test('native BREAK accepts either entity order and rejects incomplete results', () => {
  for (const reversed of [true, false]) for (const broken of [true, false]) {
    const live = new Set(['copy']);
    let after = 'previous';
    const ends = reversed
      ? { copy: [[10, 0, 0], [30, 0, 0]], suffix: [[0, 0, 0], [10, 0, 0]] }
      : { copy: [[0, 0, 0], [10, 0, 0]], suffix: [[10, 0, 0], [30, 0, 0]] };
    const rt = runtime({
      b2_curve_dist_at_point: () => 10,
      b2_curve_total_length: e => after === 'previous' ? 30 : e === 'copy'
        ? (reversed ? 20 : 10) : (reversed ? 10 : 20),
      b2_point_on_curve_p: () => true,
      'vlax-curve-getstartpoint': e => after === 'previous' ? [0, 0, 0] : ends[e][0],
      'vlax-curve-getendpoint': e => after === 'previous' ? [30, 0, 0] : ends[e][1],
      entlast: () => after,
      entget: e => live.has(e) ? e : null,
      b2_breakatpoint: () => { if (broken) { after = 'suffix'; live.add(after); } return null; },
      b2_delete_ent: e => live.delete(e),
    });
    const result = rt.invoke('b2_split_copy_at_point', ['copy', [10, 0, 0]]);
    assert.deepEqual(result, broken ? ['copy', 'suffix'] : null);
    assert.equal(live.size, broken ? 2 : 0);
    assert.deepEqual(rt.get('b2temps'), broken ? ['suffix'] : null);
  }
});

test('guide is shortened to 1.5 implement lengths before OFFSET, in both orientations', () => {
  for (const jointDist of [0, 120]) {
    const cuts = [];
    const rt = runtime({
      b2_copy_entity: () => 'copy',
      b2_break_copy_keep_toward: (e, point, ref) => { cuts.push([point, ref]); return e; },
      b2_curve_total_length: () => 120,
      b2_curve_dist_at_point: () => jointDist,
      'vlax-curve-getpointatdist': (_, dist) => [dist, 0, 0],
    });
    const length = 36.578 * 1.5;
    assert.equal(rt.invoke('b2_guide_temp_segment', ['guide', 'joint', 'pick', length]), 'copy');
    assert.deepEqual(cuts, [['joint', 'pick'], [[jointDist === 0 ? length : 120 - length, 0, 0], 'joint']]);
  }
});

test('header local window keeps both sides and measures cuts on the original curve', () => {
  const cuts = [];
  const rt = runtime({
    b2_copy_entity: () => 'copy',
    b2_curve_total_length: () => 200,
    b2_curve_dist_at_point: () => 100,
    'vlax-curve-getpointatdist': (e, d) => { assert.equal(e, 'original'); return [d, 0, 0]; },
    b2_break_copy_keep_toward: (e, point, ref) => { cuts.push([e, point, ref]); return e; },
  });
  assert.equal(rt.invoke('b2_header_temp_segment', ['original', 'joint', 30]), 'copy');
  assert.deepEqual(cuts, [['copy', [70, 0, 0], 'joint'], ['copy', [130, 0, 0], 'joint']]);
});

test('shared solver retries the same header side locally and exposes a nonintersecting pair to debug', () => {
  const candidates = [];
  const removed = [];
  const rt = runtime({
    b2_offset_candidates_signed: e => {
      candidates.push(e);
      return [[`${e}-offset`, 1]];
    },
    b2_offset_side_score: e => e === 'short-header' ? 10 : -10,
    b2_dist_to_ent: () => 1,
    b2_header_temp_segment: () => 'short-header',
    b2_find_offset_intersection: () => null,
    b2_delete_ent: e => removed.push(e),
    entget: e => e,
  });
  const result = rt.invoke('b2_offset_pair_for_maneuver', ['full-header', 'guide', 10, 11, 'cab-pick', 'guide-pick', 'joint', 30]);
  assert.deepEqual(candidates, ['full-header', 'short-header', 'guide']);
  assert.deepEqual(result, ['short-header-offset', 'guide-offset', null, null, 'short-header']);
  assert.deepEqual(removed, ['full-header-offset']);
  assert.match(rt.get('offseterror'), /1.000 m/);
});

test('disabled connection and circle cutting remain disabled during commit', () => {
  const live = new Set(['original']);
  let rt;
  const make = e => { live.add(e); return e; };
  rt = runtime({
    entget: e => live.has(e) ? e : null,
    entdel: e => { live.delete(e); return e; },
    b2_copy_entity: () => rt.invoke('b2_track_temp', [make('copy')]),
    b2_split_copy_at_point: () => ['copy', rt.invoke('b2_track_temp', [make('other')])],
    b2_circle_full_directional: () => [make('giro')],
    b2_circle_entity: () => make('outer'),
    b2_delete_ent: e => live.delete(e),
  }, { ent: 'original', '*bota_cortar_circulo*': null, '*bota_conectar_cab*': null });
  assert.equal(rt.invoke('b2_commit_maneuver'), true);
  assert.deepEqual([...live].sort(), ['copy', 'giro', 'other', 'outer']);
  assert.ok(!rt.calls.some(([name]) => name === 'b2_join_two' || name === 'b2_circle_gap_directional'));
  assert.equal(rt.get('*bota_cortar_circulo*'), null);
  assert.equal(rt.get('*bota_conectar_cab*'), null);
});

test('centre failure retries a local header with the same reference, then commits only valid tangency', () => {
  for (const succeeds of [true, false]) {
    const offsetCalls = [];
    const headerCuts = [];
    let committed = false;
    const rt = runtime({
      b2_clear_temporaries: () => null,
      b2_prepare_offsets: () => ['cab-offset', 'guide-offset', [20, 18, 0], null, null, [0, 0, 0]],
      b2_delete_ent: () => null,
      b2_offset_select_toward: (e, radius, ref) => {
        offsetCalls.push([e, radius, ref]);
        return e === 'short-header' && succeeds ? 'centre-offset' : null;
      },
      b2_header_temp_segment: (e, joint, length) => {
        headerCuts.push([e, joint, length]);
        return 'short-header';
      },
      b2_circle_entity: () => 'circle',
      b2_intersection_best: () => [5, 10, 0],
      b2_closest_point: () => [5, 0, 0],
      b2_nseg_inscribed: () => 70,
      b2_commit_maneuver: () => { committed = true; return true; },
    }, { ent: 'header', rgiro: 10 });
    rt.set('tamimpl', 36.578);
    rt.set('pguiapick', [0, 20, 0]);
    rt.invoke('b2_run_simple');
    assert.deepEqual(offsetCalls, [['header', 10, [0, 20, 0]], ['short-header', 10, [0, 20, 0]]]);
    assert.deepEqual(headerCuts, [['header', [0, 0, 0], 2 * 36.578]]);
    assert.equal(committed, succeeds);
  }
});

test('header retry uses 2 implement lengths per side only after the full offset fails', () => {
  for (const impl of [10, 30, 36.578]) for (const fullWorks of [true, false]) {
    const events = [];
    const headerCuts = [];
    const rt = runtime({
      b2_reference_intersection: () => 'joint',
      b2_guide_temp_segment: (e, joint, pick, length) => {
        assert.deepEqual([e, joint, pick, length], ['guide', 'joint', 'guide-pick', 1.5 * impl]);
        events.push('prepare-guide');
        return 'short-guide';
      },
      b2_offset_candidates_signed: e => {
        events.push(`offset-${e}`);
        return e === 'header' && !fullWorks ? null : [[`${e}-offset`, 1]];
      },
      b2_header_temp_segment: (e, joint, length) => {
        headerCuts.push([e, joint, length]);
        events.push('cut-header-copy');
        return 'short-header';
      },
      b2_signed_entry_by_side: (entries, e, ref, sameSide) => {
        assert.deepEqual([ref, sameSide], e === 'short-guide' ? ['cab-pick', null] : ['guide-pick', true]);
        return entries?.[0] ?? null;
      },
      b2_find_offset_intersection: (_, guides) => [guides[0], [1, 2, 0], null],
      b2_delete_ent: () => null,
    });
    const result = rt.invoke('b2_prepare_offsets', ['header', 'guide', 'cab-pick', 'guide-pick', impl, 0.2]);
    assert.deepEqual(headerCuts, fullWorks ? [] : [['header', 'joint', 2 * impl]]);
    assert.deepEqual(events, fullWorks
      ? ['prepare-guide', 'offset-header', 'offset-short-guide']
      : ['prepare-guide', 'offset-header', 'cut-header-copy', 'offset-short-header', 'offset-short-guide']);
    assert.deepEqual(result.slice(2, 4), [[1, 2, 0], null]);
    assert.equal(rt.get('offseterror'), null);
  }
});

test('debug cleanup retains selected offsets but deletes the calculation copies', () => {
  const live = new Set(['header-offset', 'guide-offset', 'header-copy', 'guide-copy']);
  const rt = runtime({
    entget: e => live.has(e) ? e : null,
    b2_delete_ent: e => live.delete(e),
  }, {
    b2temps: [...live], b2outputs: ['header-offset', 'guide-offset'], b2committed: true,
  });
  rt.invoke('b2_clear_temporaries');
  assert.deepEqual([...live], ['header-offset', 'guide-offset']);
});
