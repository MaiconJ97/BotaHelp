using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using BotaHelp;

if (args.Length != 3) throw new ArgumentException("Expected DLL, source LSP and JSON output paths.");

int checks = 0;
void Check(bool condition, string label)
{
    if (!condition) throw new InvalidOperationException(label);
    checks++;
    Console.WriteLine("PASS: " + label);
}

string dllPath = Path.GetFullPath(args[0]);
byte[] source = File.ReadAllBytes(args[1]);
var package = new RuntimePackage(Assembly.LoadFile(dllPath));
Check(package.SourceId == Convert.ToHexString(SHA256.HashData(source)), "DLL embeds the exact current LSP");
Check(CommandCatalog.Commands.Distinct(StringComparer.Ordinal).Count() == CommandCatalog.Commands.Length, "all command aliases are unique");
foreach (var button in CommandCatalog.Maneuvers.Concat(CommandCatalog.Connections).Concat(CommandCatalog.Settings))
    Check(CommandCatalog.IsAllowed(button.Command), "button maps to a supported command: " + button.Command);

var cases = new List<object>();
foreach (string command in CommandCatalog.Commands)
{
    string code = LispInvocation.Build(@"C:\Trabajo de Maicon\BotaHelp.Runtime.lsp", package.SourceId, command);
    Check(code.Contains("(BOTAHELP_READY \"" + command + "\")", StringComparison.Ordinal)
        && !code.Contains("(c:", StringComparison.Ordinal), "loader queues a named command after success: " + command);
    Check(LispInvocation.NamedCommand(command) == command + "\r", "repeatable named command entry: " + command);
    Check(code.EndsWith('\r') && code.Count(c => c == '\r') == 1 && !code.Contains('\n'),
        "exactly one explicit Enter submits the Ribbon command: " + command);
    cases.Add(new { command, code, named = LispInvocation.NamedCommand(command) });
}
cases.Add(new { command = "BOTAH", code = LispInvocation.Build("C:\\Area \"especial\"\\linha\n.lsp", package.SourceId, "BOTAH") });
string preload = LispInvocation.BuildLoad(@"C:\BotaHelp\runtime.lsp", package.SourceId);
Check(!preload.Contains("BOTAHELP_READY", StringComparison.Ordinal)
    && !preload.Contains("(c:", StringComparison.Ordinal), "drawing preload registers Lisp without starting an interactive command");
Check(preload.EndsWith('\r') && preload.Count(c => c == '\r') == 1,
    "preload submits exactly one expression");
cases.Add(new { command = "PRELOAD", code = preload, loadOnly = true });
try
{
    LispInvocation.NamedCommand("BOTA\r(malicious)");
    throw new InvalidOperationException("Named command injection was accepted.");
}
catch (ArgumentException)
{
    Check(true, "named command entry rejects extra input");
}
try
{
    LispInvocation.Build("runtime.lsp", package.SourceId, "BOTA) (malicious)");
    throw new InvalidOperationException("Command injection was accepted.");
}
catch (ArgumentException)
{
    Check(true, "unknown commands and injected expressions are rejected");
}

string testRoot = Path.Combine(Path.GetTempPath(), "botahelp-ribbon-tests-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(testRoot);
string adjacent = Path.Combine(testRoot, "DLL com espacos");
Directory.CreateDirectory(adjacent);
try
{
    string runtimePath = package.Materialize(adjacent, testRoot);
    Check(Path.GetDirectoryName(runtimePath) == adjacent, "runtime is placed beside the DLL when writable");
    Check(File.ReadAllBytes(runtimePath).AsSpan().SequenceEqual(source), "extracted AutoLISP is byte-identical");
    DateTime written = File.GetLastWriteTimeUtc(runtimePath);
    Check(package.Materialize(adjacent, testRoot) == runtimePath && written == File.GetLastWriteTimeUtc(runtimePath), "identical runtime is reused without rewriting");
    File.WriteAllText(runtimePath, "outdated content");
    package.Materialize(adjacent, testRoot);
    Check(File.ReadAllBytes(runtimePath).AsSpan().SequenceEqual(source), "modified or stale runtime is repaired from the embedded resource");
    string fallback = package.Materialize(Path.Combine(testRoot, "missing directory"), testRoot);
    Check(Path.GetDirectoryName(fallback) == Path.Combine(testRoot, "BotaHelp", "Runtime"), "unwritable DLL location falls back to local runtime cache");
    Check(File.ReadAllBytes(fallback).AsSpan().SequenceEqual(source), "fallback preserves the exact embedded source");
}
finally
{
    // Only a newly created, uniquely named test directory is deleted.
    string resolvedRoot = Path.GetFullPath(testRoot);
    string resolvedTemp = Path.GetFullPath(Path.GetTempPath());
    if (resolvedRoot.StartsWith(resolvedTemp, StringComparison.OrdinalIgnoreCase)
        && Path.GetFileName(resolvedRoot).StartsWith("botahelp-ribbon-tests-", StringComparison.Ordinal))
        Directory.Delete(resolvedRoot, recursive: true);
}

File.WriteAllText(args[2], JsonSerializer.Serialize(cases));
Console.WriteLine($"{checks} packaging checks passed. No AutoCAD session was opened or controlled.");
