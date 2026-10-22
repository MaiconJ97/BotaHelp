const assert = require('node:assert/strict');
const test = require('node:test');
const { forms, runtime, parse } = require('./lisp-runtime.cjs');

function drawing(blackboard, overrides = {}, globals = {}) {
  const rt = runtime({
    'vl-load-com': () => null,
    'vl-bb-ref': name => structuredClone(blackboard.get(name) ?? null),
    'vl-bb-set': (name, value) => { blackboard.set(name, structuredClone(value)); return value; },
    ...overrides,
  }, { '*botahelp_suppress_startup_help*': true, ...globals });
  rt.reload = () => {
    for (const form of forms) if (form[0] !== 'defun') rt.evaluate(form);
  };
  rt.reload();
  return rt;
}

test('all settings travel both ways between existing drawings, including false and zero', () => {
  const bb = new Map(), a = drawing(bb), b = drawing(bb);
  const values = [12, 40, 0.7, 0, 28, 1.1, 11, 0.8,
    [[80, 90, 9, 0.5], [90, 110, 11, 0.8], [110, 130, 14, 1], [130, 180, 17, 1.2]],
    0, 0, 0, 0, 0.6];
  a.set('*bota_recto_k*', 0);
  assert.equal(a.invoke('_bota_cfg_apply_values', [values]), true);
  b.invoke('_bota_session_pull');
  assert.deepEqual(b.invoke('_bota_cfg_current_values'), values);
  assert.equal(b.get('*bota_recto_k*'), 0);
  for (const key of ['*bota_conectar_cab*', '*bota_cortar_circulo*', '*bota3_densify*']) {
    assert.equal(b.get(key), false);
  }
  b.set('*bota_rgiro*', 15);
  b.invoke('_bota_session_publish');
  a.invoke('_bota_session_pull');
  assert.equal(a.get('*bota_rgiro*'), 15);
  assert.equal(a.get('*bota_recto_k*'), 0);
});

test('new drawings and reloading cannot replace the shared configuration; sessions are isolated', () => {
  const bb = new Map();
  const a = drawing(bb, {}, { '*bota_impl*': 42, '*bota_recto_k*': 0 });
  const b = drawing(bb, {}, { '*bota_impl*': 20, '*bota_recto_k*': 3 });
  assert.equal(b.get('*bota_impl*'), 42);
  b.set('*bota_impl*', 18);
  b.reload();
  assert.equal(b.get('*bota_impl*'), 42);
  const c = drawing(bb);
  assert.equal(c.get('*bota_impl*'), 42);
  assert.equal(c.get('*bota_recto_k*'), 0);
  const otherSession = drawing(new Map());
  assert.equal(otherSession.get('*bota_impl*'), 36.578);
  assert.equal(otherSession.get('*bota_recto_k*'), 0.75);
  assert.equal(a.get('*bota_impl*'), 42);
});

test('BOTAC reads shared values before displaying the dialog and Cancel publishes nothing', () => {
  const bb = new Map(), a = drawing(bb);
  let b, displayedWidth;
  b = drawing(bb, {
    'vl-filename-mktemp': () => 'dialog', open: () => 'file',
    'write-line': () => null, close: () => null, load_dialog: () => 1,
    new_dialog: () => true, set_tile: (key, value) => {
      if (key === 'tamImpl') displayedWidth = value;
    },
    itoa: String, action_tile: () => null, start_dialog: () => 0,
    unload_dialog: () => null, 'vl-file-delete': () => true,
  });
  a.set('*bota_impl*', 44);
  a.invoke('_bota_session_publish');
  const before = structuredClone([...bb]);
  b.invoke('c:botac');
  assert.equal(displayedWidth, '44');
  assert.deepEqual([...bb], before);
});

test('the real DCL accept action publishes settings while invalid edits publish nothing', () => {
  const bb = new Map();
  const tiles = { rGiro: '14', tamImpl: '38', distSeg: '0.8', seguridad: '0',
    filletR: '25', filletSeg: '1', botafR: '10', botafSeg: '1',
    joinCab: '0', cutCircle: '0', b3Densify: '0', b3TransL: '0', b3DensSeg: '0.5' };
  let completed = 0;
  const a = drawing(bb, {
    get_tile: key => tiles[key], atof: Number, itoa: String,
    _bota_cfg_number: Number,
    _bota_botaf_ranges_from_dcl: () => a.get('*botaf_auto_ranges*'),
    done_dialog: () => { completed++; }, alert: () => null,
  });
  const action = parse(a.invoke('_bota_cfg_dcl_commit_action', [1]))[0];
  a.evaluate(action);
  const b = drawing(bb);
  assert.equal(completed, 1);
  assert.equal(b.get('*bota_rgiro*'), 14);
  assert.equal(b.get('*bota_trans_l*'), 0);
  const before = structuredClone([...bb]);
  tiles.rGiro = '-1';
  a.evaluate(action);
  assert.equal(completed, 1);
  assert.deepEqual([...bb], before);
});

test('loading a valid profile publishes it; rejected and cancelled imports preserve the session', () => {
  const bb = new Map();
  let selected = 'profile', values;
  const a = drawing(bb, {
    getfiled: () => selected, getvar: () => '', alert: () => null,
    _bota_cfg_values_from_file: () => values,
  });
  values = a.invoke('_bota_cfg_current_values');
  values[0] = 16;
  a.invoke('_bota_cfg_load_interactive');
  const b = drawing(bb);
  assert.equal(b.get('*bota_rgiro*'), 16);
  const before = structuredClone([...bb]);
  values = null;
  a.invoke('_bota_cfg_load_interactive');
  selected = null;
  a.invoke('_bota_cfg_load_interactive');
  assert.deepEqual([...bb], before);
  const invalid = b.invoke('_bota_cfg_current_values');
  invalid[0] = -10;
  assert.equal(b.invoke('_bota_cfg_apply_values', [invalid]), null);
  assert.deepEqual([...bb], before);
});

function commandDrawing(bb, overrides = {}) {
  const picks = [['header', [10, 0, 0]], ['guide', [0, 10, 0]]];
  return drawing(bb, {
    getvar: () => 3, setvar: () => null, trans: p => p,
    entsel: () => picks.shift() ?? null, initget: () => null,
    'vlax-curve-getclosestpointto': (_, p) => p,
    b3_validate_inputs: () => true, getpoint: () => [0, 10, 0],
    ...overrides,
  });
}

test('BOTA and BOTA2 publish accepted groups before a later geometry failure', () => {
  for (const command of ['c:bota', 'c:bota2']) {
    const bb = new Map(), inputs = command === 'c:bota' ? [18, 41, 0.6] : [18, 41, 0, 0.6];
    const a = commandDrawing(bb, {
      getkword: () => 'C', getdist: () => inputs.shift(),
      'vlax-curve-getendparam': () => { throw Error('geometry failure'); },
      b2_run_simple: () => { throw Error('geometry failure'); },
    });
    if (command === 'c:bota') a.invoke(command); // Native error is caught by the command.
    else assert.throws(() => a.invoke(command), /geometry failure/);
    const b = drawing(bb);
    assert.equal(b.get('*bota_rgiro*'), 18);
    assert.equal(b.get('*bota_impl*'), 41);
    assert.equal(b.get('*bota_distseg*'), 0.6);
  }
});

test('BOTA3 preserves a confirmed radius when the following prompt is cancelled', () => {
  const bb = new Map();
  let count = 0;
  const a = commandDrawing(bb, {
    getkword: () => 'R', getdist: () => {
      if (count++ === 0) return 19;
      throw Error('cancelled');
    },
  });
  assert.throws(() => a.invoke('b3_command_body'), /cancelled/);
  assert.equal(drawing(bb).get('*bota_rgiro*'), 19);
});

test('BOTAFILLET manual adjustments are shared before native geometry operations', () => {
  const bb = new Map(), inputs = [23, 0.55];
  const a = commandDrawing(bb, {
    getkword: () => 'R', getdist: () => inputs.shift(),
    bf_curve_valid_p: () => true, bf_intersections: () => [[0, 0, 0]],
    bf_closest_point: (_, p) => p,
    bf_break_keep_side: () => { throw Error('geometry failure'); },
  });
  assert.throws(() => a.invoke('c:botafillet'), /geometry failure/);
  const b = drawing(bb);
  assert.equal(b.get('*botaf_fillet_r*'), 23);
  assert.equal(b.get('*botaf_fillet_seg*'), 0.55);
});

test('BOTA3 synchronizes zero straight factor and invalid radii do not overwrite the session', () => {
  for (const [mode, inputs, expectedFactor] of [['L', [], 0], ['R', [-1, 0], 0.75]]) {
    const bb = new Map();
    const a = commandDrawing(bb, {
      getkword: () => mode, getreal: () => 0, getdist: () => inputs.shift(),
      b3_selected_guide_pieces: () => null, b3_joint_on_selected_guide: () => null,
      b3_local_guide_from_pick: () => null,
    });
    a.invoke('b3_command_body');
    const b = drawing(bb);
    assert.equal(b.get('*bota_recto_k*'), expectedFactor);
    assert.equal(b.get('*bota_rgiro*'), 10);
    assert.equal(b.get('*bota_fillet_r*'), 30);
  }
});

test('typed commands and aliases pull the latest settings even when no entity is selected', () => {
  const bb = new Map(), a = drawing(bb);
  for (const command of ['c:bota', 'c:bota2', 'c:b2', 'c:bota3', 'c:b3',
    'c:botam', 'c:botafillet', 'c:botaf', 'c:bf']) {
    const b = drawing(bb, { 'vl-load-com': () => null, getvar: () => 3,
      setvar: () => null, entsel: () => null });
    a.set('*bota_impl*', a.get('*bota_impl*') + 1);
    a.invoke('_bota_session_publish');
    b.invoke(command);
    assert.equal(b.get('*bota_impl*'), a.get('*bota_impl*'), command);
  }
});
