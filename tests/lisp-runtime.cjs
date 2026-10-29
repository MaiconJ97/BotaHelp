// Source-level regressions with simulated CAD calls, not a Civil 3D emulator.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const source = fs.readFileSync(path.join(__dirname, '../bota_help.lsp'), 'utf8');
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
  const blackboard = new Map();
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
    cons: (a, b) => b == null || Array.isArray(b) ? [a, ...(b || [])] : { pair: true, car: a, cdr: b },
    car: a => a?.pair ? a.car : a?.[0] ?? null,
    cdr: a => a?.pair ? a.cdr : nil(a?.slice(1)),
    cadr: a => a?.[1] ?? null,
    caddr: a => a?.[2] ?? null,
    cadddr: a => a?.[3] ?? null,
    nth: (i, a) => a?.[i] ?? null,
    append: (...items) => nil(items.flatMap(item => item || [])),
    reverse: a => nil([...(a || [])].reverse()),
    length: a => (a || []).length,
    member: (a, list) => list?.includes(a) ? list.slice(list.indexOf(a)) : null,
    not: a => !truth(a),
    numberp: a => typeof a === 'number' && Number.isFinite(a),
    listp: a => a == null || Array.isArray(a),
    boundp: name => scopes.some(scope => scope.has(name)),
    'vl-bb-ref': name => blackboard.get(name) ?? null,
    'vl-bb-set': (name, value) => { blackboard.set(name, value); return value; },
    type: a => typeof a === 'string' ? 'str' : typeof a === 'number' ? 'real' : null,
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
    atan: (a, b) => b === undefined ? Math.atan(a) : Math.atan2(a, b),
    sin: Math.sin,
    cos: Math.cos,
    min: Math.min,
    max: Math.max,
    distance: (a, b) => Math.hypot(...a.map((value, i) => value - b[i])),
    strcat: (...parts) => parts.join(''),
    rtos: value => String(value),
    prompt: () => null,
    princ: () => null,
    'vl-catch-all-error-p': value => value instanceof Error,
    fix: Math.trunc,
    float: a => Number(a),
    last: a => Array.isArray(a) ? (a.length ? a[a.length - 1] : null) : null,
    assoc: (key, list) => {
      if (!Array.isArray(list)) return null;
      for (const item of list) {
        if (item?.pair && item.car === key) return item;
        if (Array.isArray(item) && item[0] === key) return item;
      }
      return null;
    },
    'vl-catch-all-apply': (fn, args) => {
      try { return invoke(fn, args || []); } catch (error) { return error; }
    },
    ...overrides,
  };
  function invoke(name, args = []) {
    calls.push([name, args]);
    if (builtins[name]) return builtins[name](...args);
    const def = Array.isArray(name) && name[0] === 'lambda'
      ? ['defun', '<lambda>', ...name.slice(1)] : definitions.get(name);
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
    // Definitions (including nested helpers) are collected from the source above.
    if (op === 'defun') return args[0];
    if (op === 'quote') {
      const literal = value => Array.isArray(value) ? value.map(literal)
        : value && typeof value === 'object' && 'str' in value ? value.str : value;
      return literal(args[0]);
    }
    if (op === 'progn') return sequence(args);
    if (op === 'cond') {
      for (const clause of args) {
        if (!Array.isArray(clause)) continue;
        const testVal = evaluate(clause[0]);
        if (truth(testVal)) return clause.length > 1 ? sequence(clause.slice(1)) : testVal;
      }
      return null;
    }
    if (op === 'if') return evaluate(truth(evaluate(args[0])) ? args[1] : args[2]);
    if (op === 'setq') {
      let result;
      for (let i = 0; i < args.length; i += 2) result = set(args[i], evaluate(args[i + 1]));
      return result;
    }
    if (op === 'and') return args.every(arg => truth(evaluate(arg)));
    if (op === 'or') return args.some(arg => truth(evaluate(arg)));
    if (op === 'while') {
      let result = null, iterations = 0;
      while (truth(evaluate(args[0]))) {
        if (++iterations > 100000) throw Error('Unbounded loop in test');
        result = sequence(args.slice(1));
      }
      return result;
    }
    if (op === 'repeat') {
      let result = null;
      for (let i = 0, n = evaluate(args[0]); i < n; i++) result = sequence(args.slice(1));
      return result;
    }
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
  return { invoke, get, set, calls, evaluate };
}


module.exports = { forms, definitions, walk, runtime, truth, parse };
