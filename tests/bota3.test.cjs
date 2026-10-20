const assert = require('node:assert/strict');
const test = require('node:test');
const { forms, definitions, walk, runtime } = require('./lisp-runtime.cjs');

test('BOTA3 command, initialization and pipeline have valid structure and helper arities', () => {
  for (const name of ['c:bota3', '_bota3_define_helpers', '_bota3_define_pipeline', 'b3_command_body']) {
    assert.ok(forms.some(f => f[0] === 'defun' && f[1] === name), name);
    walk(definitions.get(name), node => {
      if (node[0] === 'if') assert.ok(node.length === 3 || node.length === 4, `IF arity: ${JSON.stringify(node).slice(0, 120)}`);
      if (node[0] === 'setq') {
        assert.equal(node.length % 2, 1, 'SETQ pairs');
        for (let i = 1; i < node.length; i += 2) assert.notEqual(node[i], 't');
      }
      if (node[0] === 'defun') assert.ok(!node[2].includes('t'));
      if (typeof node[0] === 'string' && node[0].startsWith('b3_')) {
        const def = definitions.get(node[0]);
        assert.ok(def, node[0]);
        const slash = def[2].indexOf('/');
        assert.equal(node.length - 1, slash < 0 ? def[2].length : slash, node[0]);
      }
    });
  }
});

test('guide pieces returns straight segments for zero bulge', () => {
  const rt = runtime({
    'vlax-curve-getendparam': () => 1,
    'vlax-curve-getpointatparam': (_, i) => i === 0 ? [0, 0, 0] : [10, 0, 0],
    'vlax-curve-getdistatparam': (_, i) => i === 0 ? 0 : 10,
    'vlax-ename->vla-object': e => e,
    'vla-getbulge': () => 0.0,
  });
  assert.deepEqual(rt.invoke('b3_guide_pieces', ['guide']), [
    [[0, 0, 0], [10, 0, 0], 0, 10]
  ]);
});

function returningGuide(reverse = false, thirdPass = false) {
  let pieces = [
    [[0, -20, 0], [0, 200, 0], 0, 220],
    [[0, 200, 0], [36, 200, 0], 220, 256],
    [[36, 200, 0], [36, -20, 0], 256, 476],
  ];
  if (thirdPass) pieces.push([[36, -20, 0], [72, -20, 0], 476, 512],
    [[72, -20, 0], [72, 200, 0], 512, 732]);
  const total = pieces.at(-1)[3];
  const station = point => {
    const d = point[0] < 18 ? point[1] + 20
      : point[0] < 54 ? 456 - point[1] : 532 + point[1];
    return reverse ? total - d : d;
  };
  if (reverse) pieces = pieces.reverse().map(([a, b, da, db]) => [b, a, total - db, total - da]);
  return { pieces, station };
}

function returningFillet(reverse, tangentDistance = 15) {
  const { pieces, station } = returningGuide(reverse);
  const anchor = [Math.cos(Math.PI / 6) * tangentDistance, tangentDistance / 2, 0];
  const centre = [anchor[0] - 5, anchor[1] + Math.sqrt(75), 0];
  const rt = runtime({
    b2_intersection_best: () => [0, 0, 0],
    b2_real_intersections: () => [[0, 0, 0], [36, 36 / Math.sqrt(3), 0]],
    b2_curve_dist_at_point: (_, point) => station(point),
    b3_guide_pieces: () => pieces,
    'vlax-curve-getendpoint': () => reverse ? [0, -20, 0] : [36, -20, 0],
    'vlax-curve-getstartpoint': () => reverse ? [36, -20, 0] : [0, -20, 0],
    angle: (a, b) => Math.atan2(b[1] - a[1], b[0] - a[0]),
    b3_closest_point: (_, point) => point,
    b3_lwpoly_styled: () => 'maneuver',
    b2_copy_entity: () => 'copy',
    b2_split_copy_at_point: () => ['tail'],
    b3_end_on: () => true,
    b3_join_chain: () => 'joined',
    itoa: String,
  }, { '*b3_ls*': 0 });
  const result = rt.invoke('b3_analytic_fillet_ls', [
    'header', 'guide', [-10, -10 / Math.sqrt(3), 0], [0, 30, 0], centre, 10, anchor,
    70, 25, 1.5, ['turn', anchor, null, -1, [anchor]],
  ]);
  return { rt, result };
}

test('BOTA3 connects to the clicked pass rather than the return 36 metres away', () => {
  for (const reverse of [false, true]) {
    const { result, rt } = returningFillet(reverse);
    assert.ok(result, rt.get('*bota3_fillet_fail*'));
    assert.ok(Math.abs(result[1][0]) < 1e-8, 'The fillet must end on the clicked x=0 pass.');
    assert.ok(result[1][1] > 30, 'A click near the crossing does not limit how far the valid fillet can connect.');
  }
});

test('BOTA3 refuses a neighboring pass when no fillet fits the selected pass', () => {
  const { result, rt } = returningFillet(false, -20);
  assert.equal(result, null);
  assert.match(rt.get('*bota3_fillet_fail*'), /Nenhum fillet/);
  assert.ok(!rt.calls.some(([name]) => name === 'b3_lwpoly_styled'));
});

test('selected guide pass is contiguous and excludes later passes with the same direction', () => {
  for (const reverse of [false, true]) for (const x of [0, 36, 72]) {
    const { pieces, station } = returningGuide(reverse, true);
    const rt = runtime({
      b3_guide_pieces: () => pieces,
      b2_curve_dist_at_point: (_, point) => station(point),
    });
    const selected = rt.invoke('b3_selected_guide_pieces', ['guide', [x, 30, 0]]);
    assert.equal(selected.length, 1);
    assert.equal(selected[0][0][0], x);
    assert.equal(selected[0][1][0], x);
  }
});

test('guide crossing and offset copy stay on the clicked pass in either drawing direction', () => {
  for (const reverse of [false, true]) for (const x of [0, 36, 72]) {
    const { pieces, station } = returningGuide(reverse, true);
    let vertices;
    const intersections = [0, 36, 72].map(a => [a, a / Math.sqrt(3), 0]);
    const rt = runtime({
      b3_guide_pieces: () => pieces,
      b2_curve_dist_at_point: (_, point) => station(point),
      b2_real_intersections: () => intersections,
      'vlax-curve-getpointatdist': (_, distance) => {
        const [a, b, da, db] = pieces.find(p => distance >= p[2] - 1e-8 && distance <= p[3] + 1e-8);
        return a.map((v, i) => v + (b[i] - v) * (distance - da) / (db - da));
      },
      b3_lwpoly_open: points => { vertices = points; return 'local-guide'; },
    });
    const selected = rt.invoke('b3_selected_guide_pieces', ['guide', [x, 60, 0]]);
    const crossing = rt.invoke('b3_joint_on_selected_guide', ['header', 'guide', [-10, 0, 0], selected]);
    assert.equal(crossing[0], x, 'A closer crossing on a neighboring pass must not replace the selected pass.');
    assert.equal(rt.invoke('b3_local_guide_from_pick', [
      'header', 'guide', [-10, 0, 0], [x, 60, 0], 50, 0.25,
    ]), 'local-guide');
    assert.ok(vertices.length > 2);
    assert.ok(vertices.every(point => Math.abs(point[0] - x) < 1e-8));
  }
});

test('lwpoly styled copies style properties and creates tracked entity', () => {
  let created = null;
  const rt = runtime({
    entget: () => [{ pair: true, car: 8, cdr: 'ROADS' }],
    entmakex: data => { created = data; return 'poly-ent'; },
    b3_track: e => e,
  });
  const res = rt.invoke('b3_lwpoly_styled', [[[0, 0, 0], [1, 1, 0]], 'style-ent']);
  assert.equal(res, 'poly-ent');
  assert.ok(created);
});

test('analytic fillet reports missing joint when curves do not intersect', () => {
  const rt = runtime({
    b3_selected_guide_pieces: () => [[[0, 0, 0], [0, 100, 0], 0, 100]],
    b2_real_intersections: () => null,
  });
  const turnData = ['ent', [0, 0, 0], [1, 1, 0], 1, [[0, 0, 0], [1, 0, 0]]];
  const res = rt.invoke('b3_analytic_fillet', [
    'header', 'guide', [0, 0, 0], [10, 0, 0], [0, 10, 0], 10, [0, 0, 0], 64, 30, 1.5, turnData
  ]);
  assert.equal(res, null);
  assert.equal(rt.get('*bota3_fillet_fail*'), 'Nao foi possivel localizar o cruzamento cabeceira x guia.');
});

test('pipeline restores originals and system variables after a partial replacement failure', () => {
  const live = new Set(['guide', 'output', 'temp']);
  const variables = new Map(['CMDECHO', 'OSMODE', 'PEDITACCEPT'].map((k, i) => [k, i + 1]));
  const initial = [...variables];
  const deleted = [];
  let ended = false;
  const rt = runtime({
    _bota2_define_helpers: () => null,
    getvar: k => variables.get(k),
    setvar: (k, v) => variables.set(k, v),
    'vlax-get-acad-object': () => 'app',
    'vla-get-activedocument': () => 'doc',
    'vla-startundomark': () => null,
    'vla-endundomark': () => { ended = true; },
    b3_stage: () => {
      rt.set('b3originals', ['header', 'guide']);
      rt.set('b3temps', ['output', 'temp']);
      throw Error('replacement failed');
    },
    'vl-catch-all-error-message': e => e.message,
    entget: e => live.has(e) ? e : null,
    entdel: e => { live.add(e); },
    b3_delete_ent: e => { deleted.push(e); live.delete(e); },
  });
  // Association pairs are dotted cons cells in AutoLISP.
  const args = ['header', 'guide', [1, 0, 0], [0, 1, 0], [0, 0, 0], 10, [0, -10, 0], [1, -10, 0], 70, 30, 1.5, 28];
  assert.equal(rt.invoke('b3_pipeline', args), null);
  assert.ok(live.has('header') && live.has('guide'));
  assert.deepEqual(deleted, ['output', 'temp']);
  assert.deepEqual([...variables], initial);
  assert.ok(ended);
});

test('BOTA3 input validation does not measure or restrict the work angle', () => {
  const rt = runtime({
    b3_open_xy_poly_p: () => true,
    b3_work_angle: () => { throw Error('Angle must not be measured.'); },
  });
  for (const degrees of [0, 45, 79, 80, 90, 120, 180]) {
    const radians = degrees * Math.PI / 180;
    assert.equal(rt.invoke('b3_validate_inputs', [
      'header', [-10, 0, 0], 'guide', [10 * Math.cos(radians), 10 * Math.sin(radians), 0],
    ]), true, String(degrees));
    assert.equal(rt.get('*bota3_fillet_fail*'), null);
  }
});

test('BOTA3 still rejects the same entity and invalid input polylines', () => {
  for (const [header, guide, invalid] of [
    ['same', 'same', null], ['header', 'guide', 'header'], ['header', 'guide', 'guide'],
  ]) {
    const rt = runtime({ b3_open_xy_poly_p: entity => entity !== invalid });
    assert.equal(rt.invoke('b3_validate_inputs', [header, [1, 0, 0], guide, [0, 1, 0]]), false);
    assert.match(rt.get('*bota3_fillet_fail*'), /polilinhas abertas/);
  }
});

test('input validation precedes entity creation in the transactional stage', () => {
  const rt = runtime({ b3_validate_inputs: () => false });
  const args = ['header', 'guide', [1, 0, 0], [0, 1, 0], [0, 0, 0], 10, [0, -10, 0], [1, -10, 0], 70, 30, 1.5, 28];
  assert.equal(rt.invoke('b3_stage', args), null);
  assert.deepEqual(rt.calls.map(([name]) => name), ['b3_stage', 'b3_validate_inputs', 'not']);
});
