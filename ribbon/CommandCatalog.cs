namespace BotaHelp;

internal sealed record ButtonSpec(string Label, string Command, string Description, string Icon);

internal static class CommandCatalog
{
    internal static readonly ButtonSpec[] Maneuvers =
    [
        new("BOTA", "BOTA", "Manobra manual pelo ponto de contato do implemento.", "turn1"),
        new("BOTA2", "BOTA2", "Manobra por cabeceira e linha guia. Atalho: B2.", "turn2"),
        new("BOTA3", "BOTA3", "Manobra com fillet e densificacao configuravel. Atalho: B3.", "turn3"),
        new("BotaM", "BOTAM", "BOTA2 com um ponto adicional para definir o lado do giro.", "turn1"),
    ];

    internal static readonly ButtonSpec[] Connections =
    [new("Fillet\nAutomatico", "BOTAFILLET", "Concordancia segmentada entre cabeceira e linha. Atalhos: BOTAF / BF.", "fillet")];

    internal static readonly ButtonSpec[] Settings =
    [
        new("Configuracao", "BOTAC", "Configurar parametros, densificacao e perfis de arquivo.", "settings"),
        new("Ajuda", "BOTAH", "Abrir a ajuda dos comandos BotaHelp.", "help"),
    ];

    internal static readonly string[] Commands =
    ["BOTA", "BOTA2", "B2", "BOTA3", "B3", "BOTAM", "BOTAFILLET", "BOTAF", "BF", "BOTAC", "BOTAH"];

    internal static bool IsAllowed(string command) => Commands.Contains(command, StringComparer.Ordinal);
}
