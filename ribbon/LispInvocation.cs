namespace BotaHelp;

internal static class LispInvocation
{
    internal static string NamedCommand(string command)
    {
        if (!CommandCatalog.IsAllowed(command))
            throw new ArgumentException("Comando BotaHelp desconhecido.", nameof(command));
        return command + "\r";
    }

    internal static string Build(string path, string sourceId, string command)
    {
        if (!CommandCatalog.IsAllowed(command))
            throw new ArgumentException("Comando BotaHelp desconhecido.", nameof(command));

        return BuildCore(path, sourceId, $"(if botahelpReady (BOTAHELP_READY {Quote(command)})) ");
    }

    internal static string BuildLoad(string path, string sourceId) => BuildCore(path, sourceId, "");

    private static string BuildCore(string path, string sourceId, string afterLoad)
    {
        // This expression only loads code. The callback queues a named command
        // after successful loading, preserving normal prompts and Enter repeat.
        // Lambda locals restore the startup-help flag if loading is cancelled.
        // The source marker lives in each drawing's AutoLISP namespace.
        return "((lambda (/ *BOTAHELP_SUPPRESS_STARTUP_HELP* botahelpReady botahelpLoadResult) " +
            "(setq *BOTAHELP_SUPPRESS_STARTUP_HELP* T botahelpReady T) " +
            $"(if (not (equal *BOTAHELP_DLL_SOURCE_ID* {Quote(sourceId)})) " +
            "(progn " +
            $"(setq botahelpLoadResult (vl-catch-all-apply 'load (list {Quote(path.Replace('\\', '/'))}))) " +
            "(if (vl-catch-all-error-p botahelpLoadResult) " +
            "(progn (setq botahelpReady nil) " +
            "(prompt (strcat \"\\nBotaHelp: falha ao carregar AutoLISP. \" " +
            "(vl-catch-all-error-message botahelpLoadResult)))) " +
            $"(setq *BOTAHELP_DLL_SOURCE_ID* {Quote(sourceId)})))) " +
            // SendStringToExecute uses carriage return as Enter. A single terminator
            // submits the expression without answering the command's first prompt.
            afterLoad + "(princ)))\r";
    }

    private static string Quote(string value) => "\"" + value
        .Replace("\\", "\\\\").Replace("\"", "\\\"")
        .Replace("\r", "\\r").Replace("\n", "\\n") + "\"";
}
