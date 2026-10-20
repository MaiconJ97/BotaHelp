// Source-level regressions with simulated CAD calls, not a Civil 3D emulator.
const assert = require('node:assert/strict');
const test = require('node:test');
const { forms, definitions, walk, runtime, truth } = require('./lisp-runtime.cjs');

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

test('BOTA2 and BOTA2DEBUG use the common tangency solver', () => {
  for (const name of ['b2_run_simple', 'c:bota2debug']) {
    let count = 0;
    walk(definitions.get(name), node => { if (node[0] === 'b2_tangent_solution') count++; });
    assert.equal(count, 1, name);
  }
});

test('short command aliases delegate to their canonical commands', () => {
  for (const [alias, target] of [['c:b2', 'c:bota2'], ['c:botaf', 'c:botafillet'], ['c:bf', 'c:botafillet']]) {
    let calls = 0;
    const rt = runtime({ [target]: () => { calls++; return null; } });
    rt.invoke(alias);
    assert.equal(calls, 1, alias);
  }
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

test('guide keeps a 0.2 implement reserve opposite the pick before OFFSET', () => {
  for (const jointDist of [0, 60, 120]) {
    const cuts = [];
    const rt = runtime({
      b2_copy_entity: () => 'copy',
      b2_break_copy_keep_toward: (e, point, ref) => { cuts.push([point, ref]); return e; },
      b2_curve_total_length: () => 120,
      b2_curve_dist_at_point: (_, point) => point === 'joint'
        ? jointDist : (jointDist === 120 ? 0 : 120),
      'vlax-curve-getpointatdist': (_, dist) => [dist, 0, 0],
    });
    const forward = 36.578 * 1.5;
    const reserve = 36.578 * 0.2;
    assert.equal(rt.invoke('b2_guide_temp_segment', ['guide', 'joint', 'pick', forward, reserve]), 'copy');
    const expected = jointDist === 0
      ? [[[forward, 0, 0], 'joint']]
      : jointDist === 120
        ? [[[120 - forward, 0, 0], 'joint']]
        : [
          [[jointDist - reserve, 0, 0], 'joint'],
          [[jointDist + forward, 0, 0], 'joint'],
        ];
    assert.deepEqual(cuts, expected);
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

test('offset pair uses the supplied local header and exposes a nonintersecting pair to debug', () => {
  const candidates = [];
  const removed = [];
  const rt = runtime({
    b2_offset_candidates_signed: e => {
      candidates.push(e);
      return [[`${e}-offset`, 1]];
    },
    b2_offset_side_score: e => e === 'local-header' ? 10 : -10,
    b2_dist_to_ent: () => 1,
    b2_find_offset_intersection: () => null,
    b2_delete_ent: e => removed.push(e),
    entget: e => e,
  });
  const result = rt.invoke('b2_offset_pair_for_maneuver', ['local-header', 'guide', 10, 11, 'cab-pick', 'guide-pick', 'joint']);
  assert.deepEqual(candidates, ['local-header', 'guide']);
  assert.deepEqual(result, ['local-header-offset', 'guide-offset', null, null]);
  assert.deepEqual(removed, []);
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

test('centre uses the prepared local header and commits only valid tangency', () => {
  for (const succeeds of [true, false]) {
    const offsetCalls = [];
    let committed = false;
    const rt = runtime({
      b2_clear_temporaries: () => null,
      b2_prepare_offsets: () => ['cab-offset', 'guide-offset', [20, 18, 0], null, 'local-header', [0, 0, 0]],
      b2_delete_ent: () => null,
      b2_offset_select_toward: (e, radius, ref) => {
        offsetCalls.push([e, radius, ref]);
        return e === 'local-header' && succeeds ? 'centre-offset' : null;
      },
      b2_circle_entity: () => 'circle',
      b2_tangent_solution: () => succeeds ? [[5, 10, 0], [5, 0, 0]] : null,
      b2_nseg_inscribed: () => 70,
      b2_commit_maneuver: () => { committed = true; return true; },
    }, { ent: 'header', rgiro: 10 });
    rt.set('tamimpl', 36.578);
    rt.set('pguiapick', [0, 20, 0]);
    rt.invoke('b2_run_simple');
    assert.deepEqual(offsetCalls, [['local-header', 10, [0, 20, 0]]]);
    assert.equal(committed, succeeds);
  }
});

test('header is limited to two implement lengths per side before every offset', () => {
  for (const impl of [10, 30, 36.578]) {
    const events = [];
    const headerCuts = [];
    const rt = runtime({
      b2_reference_intersection: () => 'joint',
      b2_guide_temp_segment: (e, joint, pick, length, reserve) => {
        assert.deepEqual([e, joint, pick, length, reserve], ['guide', 'joint', 'guide-pick', 1.5 * impl, 0.2 * impl]);
        events.push('prepare-guide');
        return 'short-guide';
      },
      b2_offset_candidates_signed: e => {
        events.push(`offset-${e}`);
        return [[`${e}-offset`, 1]];
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
    assert.deepEqual(headerCuts, [['header', 'joint', 2 * impl]]);
    assert.deepEqual(events,
      ['prepare-guide', 'cut-header-copy', 'offset-short-header', 'offset-short-guide']);
    assert.deepEqual(result.slice(2, 4), [[1, 2, 0], null]);
    assert.equal(result[4], 'short-header');
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

test('BOTA2 deletes selected offset copies when they do not intersect', () => {
  const live = new Set(['header-offset', 'guide-offset']);
  const rt = runtime({
    entget: e => live.has(e) ? e : null,
    b2_prepare_offsets: () => ['header-offset', 'guide-offset', null, null, null, 'joint'],
    b2_delete_ent: e => live.delete(e),
  }, { ent: 'header', guia: 'guide', rgiro: 10, tamimpl: 36.578 });
  rt.invoke('b2_run_simple');
  assert.deepEqual([...live], []);
});

test('tangency solver keeps the candidate nearest the offset reference', () => {
  const points = [
    [0, 10.03, 0],
    [10.02, 0, 0],
    [0, 10.06, 0],
  ];
  const rt = runtime({
    b2_real_intersections: () => points,
    b2_closest_point: (_, point) => point[0] === 0 ? [0, 0, 0] : [0, 0, 0],
  });
  assert.deepEqual(
    rt.invoke('b2_tangent_solution', ['header', 'offset', 'outer-circle', [28, 0, 0], 10, 18, [10, 0, 0]]),
    [[10, 0, 0], [0, 0, 0], [10.02, 0, 0], 0.019999999999999574, 0],
  );
  assert.equal(rt.get('tangenterror'), null);
});

test('tangency solver accepts corrections through 0.05 m and rejects larger values', () => {
  for (const correction of [0.03, 0.05, 0.051]) {
    const rt = runtime({
      b2_real_intersections: () => [[0, 10 + correction, 0]],
      b2_closest_point: () => [0, 0, 0],
    });
    const result = rt.invoke(
      'b2_tangent_solution', ['header', 'offset', 'outer-circle', [0, 28, 0], 10, 18, [0, 10, 0]],
    );
    assert.equal(Boolean(result), correction <= 0.05, `correction ${correction}`);
    if (result) {
      assert.deepEqual(result.slice(0, 2), [[0, 10, 0], [0, 0, 0]]);
      assert.ok(result[3] <= 0.050000001);
      assert.ok(result[4] <= 0.050000001);
    } else {
      assert.match(rt.get('tangenterror'), /0.050 m/);
    }
  }
});

test('tangency solver rejects a corrected centre when its external radius exceeds 0.05 m', () => {
  const rt = runtime({
    b2_real_intersections: () => [[0, 10.02, 0]],
    b2_closest_point: () => [0, 0, 0],
  });
  assert.equal(
    rt.invoke('b2_tangent_solution', ['header', 'offset', 'outer-circle', [0, 28.051, 0], 10, 18, [0, 10, 0]]),
    null,
  );
  assert.match(rt.get('tangenterror'), /0.050 m/);
});
