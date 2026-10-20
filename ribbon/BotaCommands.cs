using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.ApplicationServices;
using System.IO;
using AcadApp = Autodesk.AutoCAD.ApplicationServices.Core.Application;

namespace BotaHelp;

public sealed class BotaCommands
{
    private static readonly Lazy<RuntimePackage> Package = new(() => new(typeof(BotaCommands).Assembly));
    private static readonly HashSet<Document> PreloadAttempted = [];

    // Ribbon callbacks run outside document command context. Queue the actual command
    // name so AutoCAD owns its prompts and repeat-last-command history.
    internal static void QueueCommand(string command)
    {
        AcadApp.DocumentManager.MdiActiveDocument?.SendStringToExecute(
            LispInvocation.NamedCommand(command), true, false, true);
    }

    [LispFunction("BOTAHELP_READY")]
    public static void ResumeAfterLoad(ResultBuffer arguments)
    {
        var values = arguments?.AsArray();
        if (values is { Length: 1 } && values[0].TypeCode == (int)LispDataType.Text
            && values[0].Value is string command && CommandCatalog.IsAllowed(command))
            QueueCommand(command);
    }

    internal static void ForgetDocument(Document doc) => PreloadAttempted.Remove(doc);

    internal static void PreloadCurrentDocument()
    {
        var doc = AcadApp.DocumentManager.MdiActiveDocument;
        if (doc is null || PreloadAttempted.Contains(doc)
            || Convert.ToInt32(AcadApp.GetSystemVariable("CMDACTIVE")) != 0) return;
        // Attempt automatic loading once. A failed load must not loop on Idle;
        // clicking a button explicitly retries loading with the usual diagnostics.
        PreloadAttempted.Add(doc);
        try
        {
            if (!IsLoaded(doc)) QueueLoad(doc, null);
        }
        catch (System.Exception error)
        {
            doc.Editor.WriteMessage($"\nBotaHelp: {error.Message}\n");
        }
    }

    private static bool IsLoaded(Document doc) => string.Equals(
        doc.GetLispSymbol("*BOTAHELP_DLL_SOURCE_ID*") as string, Package.Value.SourceId,
        StringComparison.Ordinal);

    private static void QueueLoad(Document doc, string? command)
    {
        string folder = Path.GetDirectoryName(typeof(BotaCommands).Assembly.Location)
            ?? throw new InvalidOperationException("Nao foi possivel localizar a DLL.");
        RuntimePackage package = Package.Value;
        string path = package.Materialize(folder, Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData));
        string code = command is null ? LispInvocation.BuildLoad(path, package.SourceId)
            : LispInvocation.Build(path, package.SourceId, command);
        doc.SendStringToExecute(code, true, false, false);
    }

    internal static void RunFromRibbon(string command)
    {
        if (!CommandCatalog.IsAllowed(command)) throw new ArgumentException("Comando BotaHelp desconhecido.");
        var doc = AcadApp.DocumentManager.MdiActiveDocument;
        if (doc is null) return;
        if (IsLoaded(doc)) QueueCommand(command);
        else QueueLoad(doc, command);
    }

    [CommandMethod("BOTAHELPINFO")]
    public void ShowInfo()
    {
        var doc = AcadApp.DocumentManager.MdiActiveDocument;
        if (doc is null) return;
        var assembly = typeof(BotaCommands).Assembly;
        doc.Editor.WriteMessage($"\nBotaHelp DLL: {assembly.GetName().Version}\nArquivo: {assembly.Location}"
            + $"\nLSP incorporado: {Package.Value.SourceId}"
            + $"\nLSP carregado neste desenho: {doc.GetLispSymbol("*BOTAHELP_DLL_SOURCE_ID*") ?? "nenhum"}"
            + "\nComandos BOTA executados diretamente pelo AutoLISP.\n");
    }

    [CommandMethod("BOTAHELP")]
    public void ShowRibbon()
    {
        BotaHelpPlugin.ShowRibbon();
    }
}
