const assert = require('node:assert/strict');
const test = require('node:test');
const { runtime } = require('./lisp-runtime.cjs');

const add = (a, b) => a.map((v, i) => v + b[i]);
const sub = (a, b) => a.map((v, i) => v - b[i]);
const scale = (v, k) => v.map(a => a * k);
const dot = (a, b) => a.reduce((sum, v, i) => sum + v * b[i], 0);
const normal = u => [-u[1], u[0], 0];
const distance = (a, b) => Math.hypot(...sub(a, b));

function compareDirections(heading, guideAngle, reverseHeader, reverseGuide, pickDistance, guidePickDistance) {
  const rotate = angle => [Math.cos(angle), Math.sin(angle), 0];
  const h = rotate(heading), g = rotate(heading + guideAngle);
  const headerPick = scale(h, pickDistance), guidePick = scale(g, guidePickDistance);
  const models = new Map();
  const line = (name, u, offset = 0) => models.set(name, { u, p: scale(normal(u), offset) });
  line('header', scale(h, reverseHeader ? -1 : 1));
  line('guide', scale(g, reverseGuide ? -1 : 1));
  models.set('headerLocal', models.get('header'));
  models.set('guideLocal', models.get('guide'));
  function closest(name, point) {
    const { u, p } = models.get(name);
    return add(p, scale(u, dot(sub(point, p), u)));
  }
  function intersect(first, second) {
    const a = models.get(first), b = models.get(second);
    const d = sub(b.p, a.p), determinant = a.u[0] * b.u[1] - a.u[1] * b.u[0];
    return add(a.p, scale(a.u, (d[0] * b.u[1] - d[1] * b.u[0]) / determinant));
  }
  function offset(name, amount) {
    const out = name + ':' + amount;
    const model = models.get(name);
    models.set(out, { u: model.u, p: add(model.p, scale(normal(model.u), amount)) });
    return out;
  }
  const common = {
    angle: (a, b) => Math.atan2(b[1] - a[1], b[0] - a[0]),
    'vlax-curve-getclosestpointto': closest,
    'vlax-curve-getendparam': () => 1,
    'vlax-curve-getpointatparam': (name, index) => add(models.get(name).p, scale(models.get(name).u, index ? 200 : -200)),
    b3_offset_all: (name, amount) => [offset(name, amount)],
    b3_intersection_best: intersect,
    b3_delete_ent: () => null,
    b2_delete_ent: () => null,
    b2_lwpoly_open: () => 'b2-turn',
    b3_lwpoly_open: () => 'b3-turn',
    entget: name => name,
  };
  let selections = [['header', headerPick], ['guide', guidePick]], actual;
  const b3 = runtime({
    ...common,
    _bota_init_boolean_options: () => null,
    getvar: () => 3, setvar: () => null, trans: point => point,
    entsel: () => selections.shift(), initget: () => null, getkword: () => null,
    b3_validate_inputs: () => true,
    b3_local_guide_from_pick: () => 'guideLocal',
    b3_selected_guide_pieces: () => [],
    b3_joint_on_selected_guide: () => [0, 0, 0],
    b3_local_poly_from_curve: (name, reference, radius) => {
      assert.equal(name, 'header');
      assert.ok(distance(reference, [0, 0, 0]) < 1e-8, 'Header window must be anchored at the crossing.');
      assert.equal(radius, 2 * 36.578);
      return 'headerLocal';
    },
    b3_pipeline: (_, __, ___, ____, centre, radius, anchor, cutRef) => {
      actual = { centre, anchor, cutRef }; return true;
    },
  }, { '*bota_conectar_cab*': true, '*bota_cortar_circulo*': true });
  b3.invoke('b3_command_body');

  // BOTA2 remains the reference. Only native CAD operations are supplied here;
  // its centre selection and cut-reference calculations run from the real LSP.
  const hOffset = offset('header', Math.sign(dot(normal(models.get('header').u), guidePick)) * 36.578 / 2);
  const gOffset = offset('guide', -Math.sign(dot(normal(models.get('guide').u), headerPick)) * (36.578 / 2 + 0.2));
  const vertex = intersect(hOffset, gOffset);
  let circle, expected, b2;
  b2 = runtime({
    ...common,
    b2_clear_temporaries: () => null,
    b2_prepare_offsets: () => [hOffset, gOffset, vertex, null, 'headerLocal', [0, 0, 0]],
    b2_offset_select_toward: () => offset('header', Math.sign(dot(normal(models.get('header').u), guidePick)) * 10),
    b2_circle_entity: (point, radius) => { circle = { point, radius }; return 'circle'; },
    b2_real_intersections: name => {
      const { u, p } = models.get(name), delta = sub(p, circle.point);
      const b = dot(delta, u), determinant = b * b - (dot(delta, delta) - circle.radius * circle.radius);
      if (determinant < 0) return null;
      return [add(p, scale(u, -b + Math.sqrt(determinant))), add(p, scale(u, -b - Math.sqrt(determinant)))];
    },
    b2_commit_maneuver: () => {
      expected = { centre: b2.get('centro'), anchor: b2.get('ptang'), cutRef: b2.get('pcutref') };
    },
  }, { ent: 'header', guia: 'guide', pcab: headerPick, pguiapick: guidePick,
    rgiro: 10, tamimpl: 36.578, seguridad: 0.2, distseg: 0.9 });
  b2.invoke('b2_run_simple');
  const turnFirst = actual && b3.invoke('b3_circle_gap_directional',
    [actual.centre, 10, actual.anchor, actual.cutRef, 70, null])[4][1];
  const referenceFirst = expected && b2.invoke('b2_circle_gap_directional',
    [expected.centre, 10, expected.anchor, expected.cutRef, 70, null])[4][1];
  return { actual, expected, h, turnFirst, referenceFirst };
}

test('BOTA3 follows BOTA2 centre, tangency and turn direction regardless of drawing orientation', () => {
  for (const heading of [0, 0.4, Math.PI / 2, 2.4, Math.PI, 4.7])
    for (const guideAngle of [Math.PI / 3, Math.PI * 5 / 9, Math.PI * 13 / 18])
      for (const reverseHeader of [false, true]) for (const reverseGuide of [false, true])
        for (const pickDistance of [-45, -20, 20, 45]) for (const guidePickDistance of [-20, 20]) {
          const label = JSON.stringify({ heading, guideAngle, reverseHeader, reverseGuide, pickDistance, guidePickDistance });
          const { actual, expected, h, turnFirst, referenceFirst } = compareDirections(heading, guideAngle, reverseHeader, reverseGuide, pickDistance, guidePickDistance);
          assert.ok(expected, 'BOTA2 must have a valid reference solution: ' + label);
          assert.ok(actual, 'BOTA3 must find the same maneuver: ' + label);
          assert.ok(distance(actual.centre, expected.centre) < 1e-6, 'Centre differs from BOTA2: ' + label);
          assert.ok(distance(actual.anchor, expected.anchor) < 1e-6, 'Tangency differs from BOTA2: ' + label);
          assert.ok(dot(sub(actual.cutRef, actual.anchor), h) * dot(sub(expected.cutRef, expected.anchor), h) > 0,
            'Turn direction differs from BOTA2: ' + label);
          assert.ok(distance(turnFirst, referenceFirst) < 1e-6, 'Actual circular traversal differs from BOTA2: ' + label);
        }
});
