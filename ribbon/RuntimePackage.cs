using System.Reflection;
using System.IO;
using System.Security.Cryptography;

namespace BotaHelp;

internal sealed class RuntimePackage
{
    private const string ResourceName = "BotaHelp.Runtime.lsp";
    private readonly byte[] _source;
    internal string SourceId { get; }

    internal RuntimePackage(Assembly assembly)
    {
        using Stream stream = assembly.GetManifestResourceStream(ResourceName)
            ?? throw new InvalidOperationException("O AutoLISP incorporado nao foi encontrado na DLL.");
        using var memory = new MemoryStream();
        stream.CopyTo(memory);
        _source = memory.ToArray();
        SourceId = Convert.ToHexString(SHA256.HashData(_source));
    }

    internal string Materialize(string assemblyDirectory, string localAppData)
    {
        string fileName = $"BotaHelp.Runtime-{SourceId[..16]}.lsp";
        // Adjacent to the DLL normally shares the location already approved by the user.
        // Never changes SECURELOAD, TRUSTEDPATHS or any other AutoCAD security setting.
        try
        {
            return WriteVerified(Path.Combine(assemblyDirectory, fileName));
        }
        catch (System.Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            string fallback = Path.Combine(localAppData, "BotaHelp", "Runtime");
            Directory.CreateDirectory(fallback);
            return WriteVerified(Path.Combine(fallback, fileName));
        }
    }

    private string WriteVerified(string path)
    {
        if (File.Exists(path) && File.ReadAllBytes(path).AsSpan().SequenceEqual(_source))
            return path;

        string temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            File.WriteAllBytes(temporary, _source);
            File.Move(temporary, path, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
        return path;
    }
}
