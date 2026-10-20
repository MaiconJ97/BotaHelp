const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { forms, definitions, parse, walk, runtime } = require('./lisp-runtime.cjs');

test('maneuver commands belong to the original Lisp and are not shadowed by managed wrappers', () => {
  const source = fs.readFileSync(path.join(__dirname, '../ribbon/BotaCommands.cs'), 'utf8');
  for (const name of ['BOTA', 'BOTA2', 'B2', 'BOTA3', 'B3', 'BOTAM', 'BOTAFILLET', 'BOTAF', 'BF', 'BOTAC', 'BOTAH']) {
    assert.ok(definitions.has('c:' + name.toLowerCase()), name);
    assert.ok(!source.includes(`[CommandMethod("${name}")]`), 'Do not register a second command with the same name: ' + name);
  }
  assert.ok(!source.includes('AcadApp.Invoke('), 'Interactive routines run as native Lisp commands.');
});

test('DLL loader loads once per drawing, resumes each named command, and restores startup-help state', context => {
  const file = process.env.BOTAHELP_INVOCATION_CASES;
  if (!file) return context.skip('Generated C# invocations are supplied by ribbon/build.ps1.');
  for (const { command, code, loadOnly } of JSON.parse(fs.readFileSync(file, 'utf8'))) {
    let loads = 0, commands = 0;
    const overrides = {
      load: () => {
        loads++;
        assert.equal(rt.get('*botahelp_suppress_startup_help*'), true);
        return null; // Successful source loading normally ends with (princ), returning nil.
      },
      botahelp_ready: name => { assert.equal(name, command); commands++; },
    };
    const rt = runtime(overrides, { '*botahelp_suppress_startup_help*': false });
    const ast = parse(code)[0];
    rt.evaluate(ast);
    rt.evaluate(ast);
    assert.equal(loads, 1, command);
    assert.equal(commands, loadOnly ? 0 : 2, command);
    assert.equal(rt.get('*botahelp_suppress_startup_help*'), false);
    let secondDrawingLoads = 0;
    const second = runtime({ ...overrides, load: () => { secondDrawingLoads++; } });
    second.evaluate(ast);
    assert.equal(secondDrawingLoads, 1, 'Each new drawing loads its own Lisp functions.');
  }
});

test('load failure prevents command execution and is retried on the next invocation', context => {
  const file = process.env.BOTAHELP_INVOCATION_CASES;
  if (!file) return context.skip('Generated C# invocations are supplied by ribbon/build.ps1.');
  const { command, code } = JSON.parse(fs.readFileSync(file, 'utf8'))[0];
  let loads = 0, commands = 0, message;
  const rt = runtime({
    load: () => { if (++loads === 1) throw Error('trusted location required'); },
    'vl-catch-all-error-message': error => error.message,
    prompt: text => { message = text; },
    botahelp_ready: name => { assert.equal(name, command); commands++; },
  });
  const ast = parse(code)[0];
  rt.evaluate(ast);
  assert.equal(commands, 0);
  assert.equal(rt.get('*botahelp_dll_source_id*'), null);
  assert.equal(rt.get('*botahelp_suppress_startup_help*'), null);
  assert.ok(message.includes('trusted location required'));
  rt.evaluate(ast);
  assert.equal(loads, 2);
  assert.equal(commands, 1);
});

test('load cancellation restores scoped state and prevents the interactive command from starting', context => {
  const file = process.env.BOTAHELP_INVOCATION_CASES;
  if (!file) return context.skip('Generated C# invocations are supplied by ribbon/build.ps1.');
  const { command, code } = JSON.parse(fs.readFileSync(file, 'utf8'))[0];
  let loads = 0;
  const rt = runtime({
    load: () => { loads++; throw Error('Function cancelled'); },
    'vl-catch-all-error-message': error => error.message,
    prompt: () => {},
    botahelp_ready: () => { assert.fail('Cancelled loading cannot start a command.'); },
  }, { '*botahelp_suppress_startup_help*': false });
  const ast = parse(code)[0];
  rt.evaluate(ast);
  assert.equal(rt.get('*botahelp_suppress_startup_help*'), false);
  assert.equal(rt.get('*botahelp_dll_source_id*'), null);
  rt.evaluate(ast);
  assert.equal(loads, 2);
});

test('manual LSP loading still shows help, and only the DLL can suppress startup help locally', () => {
  const guarded = forms.find(form => form[0] === 'if' && Array.isArray(form[1])
    && form[1][0] === 'not' && form[1][1] === '*botahelp_suppress_startup_help*');
  assert.ok(guarded);
  assert.deepEqual(guarded[2], ['_bota_show_help']);
});

test('generated DLL invocations are valid, scope the silent flag, and guard execution on successful load', context => {
  const file = process.env.BOTAHELP_INVOCATION_CASES;
  if (!file) return context.skip('Run the packaging test executable first to supply generated C# invocations.');
  for (const { command, code, named, loadOnly } of JSON.parse(fs.readFileSync(file, 'utf8'))) {
    if (named) assert.equal(named, command + '\r');
    assert.ok(code.endsWith('\r'), 'Ribbon command must submit with Enter.');
    assert.equal((code.match(/\r/g) || []).length, 1, 'Do not consume the first interactive prompt.');
    assert.ok(!code.includes('\n'), 'Use the AutoCAD carriage-return terminator.');
    const parsed = parse(code);
    assert.equal(parsed.length, 1, command);
    const lambdaCall = parsed[0];
    const lambda = lambdaCall[0];
    assert.equal(lambda[0], 'lambda');
    assert.ok(lambda[1].includes('*botahelp_suppress_startup_help*'));
    let guarded = false;
    let loaded = false;
    walk(lambda, node => {
      if (node[0] === 'vl-catch-all-apply' && node[1]?.[1] === 'load') loaded = true;
      if (node[0] === 'if' && node[1] === 'botahelpready' && node[2]?.[0] === 'botahelp_ready'
          && node[2][1]?.str === command) guarded = true;
      assert.ok(!(typeof node[0] === 'string' && node[0].startsWith('c:')),
        'Interactive commands must start by name after the loader returns.');
      if (node[0] === 'if') assert.ok(node.length === 3 || node.length === 4);
      assert.notEqual(node[0], 'setvar', 'The loader does not change AutoCAD security variables.');
    });
    assert.ok(loaded, command);
    assert.equal(guarded, !loadOnly, command);
  }
});
