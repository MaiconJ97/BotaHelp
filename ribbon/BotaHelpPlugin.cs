using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;
using System.Windows.Input;
using AcadApp = Autodesk.AutoCAD.ApplicationServices.Core.Application;

[assembly: ExtensionApplication(typeof(BotaHelp.BotaHelpPlugin))]
[assembly: CommandClass(typeof(BotaHelp.BotaCommands))]

namespace BotaHelp;

public sealed class BotaHelpPlugin : IExtensionApplication
{
    private const string TabId = "BUSANELLO_BOTAHELP_RIBBON";
    private static BotaHelpPlugin? _instance;
    private bool _idleSubscribed;
    private bool _updating;
    private bool _activate;
    private readonly HashSet<Document> _watchedDocuments = [];

    public void Initialize()
    {
        _instance = this;
        ComponentManager.ItemInitialized += OnItemInitialized;
        AcadApp.SystemVariableChanged += OnSystemVariableChanged;
        AcadApp.DocumentManager.DocumentCreated += OnDocumentCreated;
        AcadApp.DocumentManager.DocumentActivated += OnDocumentActivated;
        AcadApp.DocumentManager.DocumentToBeDestroyed += OnDocumentToBeDestroyed;
        foreach (Document doc in AcadApp.DocumentManager) WatchDocument(doc);
        Schedule(activate: true);
        Write("BotaHelp carregado. Aba BotaHelp no Ribbon; comando BOTAHELP para exibi-la.");
    }

    public void Terminate()
    {
        UnsubscribeIdle();
        ComponentManager.ItemInitialized -= OnItemInitialized;
        AcadApp.SystemVariableChanged -= OnSystemVariableChanged;
        AcadApp.DocumentManager.DocumentCreated -= OnDocumentCreated;
        AcadApp.DocumentManager.DocumentActivated -= OnDocumentActivated;
        AcadApp.DocumentManager.DocumentToBeDestroyed -= OnDocumentToBeDestroyed;
        foreach (Document doc in _watchedDocuments.ToArray()) UnwatchDocument(doc);
        var ribbon = ComponentManager.Ribbon;
        var tab = ribbon?.Tabs.FirstOrDefault(item => item.Id == TabId);
        if (tab is not null) ribbon!.Tabs.Remove(tab);
        _instance = null;
    }

    internal static void ShowRibbon()
    {
        _instance?.Schedule(activate: true);
        AcadApp.DocumentManager.MdiActiveDocument?.SendStringToExecute("_.RIBBON ", true, false, false);
    }

    private void OnItemInitialized(object? sender, EventArgs args)
    {
        if (!_updating) Schedule(activate: false);
    }

    private void OnSystemVariableChanged(object? sender, SystemVariableChangedEventArgs args)
    {
        if (args.Name.Equals("WSCURRENT", StringComparison.OrdinalIgnoreCase)) Schedule(activate: false);
    }

    private void WatchDocument(Document doc)
    {
        if (!_watchedDocuments.Add(doc)) return;
        doc.CommandWillStart += OnDocumentExecutionChanged;
        doc.CommandEnded += OnDocumentExecutionChanged;
        doc.CommandCancelled += OnDocumentExecutionChanged;
        doc.CommandFailed += OnDocumentExecutionChanged;
        doc.LispWillStart += OnDocumentExecutionChanged;
        doc.LispEnded += OnDocumentExecutionChanged;
        doc.LispCancelled += OnDocumentExecutionChanged;
    }

    private void UnwatchDocument(Document doc)
    {
        if (!_watchedDocuments.Remove(doc)) return;
        BotaCommands.ForgetDocument(doc);
        doc.CommandWillStart -= OnDocumentExecutionChanged;
        doc.CommandEnded -= OnDocumentExecutionChanged;
        doc.CommandCancelled -= OnDocumentExecutionChanged;
        doc.CommandFailed -= OnDocumentExecutionChanged;
        doc.LispWillStart -= OnDocumentExecutionChanged;
        doc.LispEnded -= OnDocumentExecutionChanged;
        doc.LispCancelled -= OnDocumentExecutionChanged;
    }

    private void OnDocumentCreated(object? sender, DocumentCollectionEventArgs args)
    {
        WatchDocument(args.Document);
        Schedule(activate: false);
    }

    private void OnDocumentActivated(object? sender, DocumentCollectionEventArgs args)
    {
        WatchDocument(args.Document);
        Schedule(activate: false);
    }

    private void OnDocumentToBeDestroyed(object? sender, DocumentCollectionEventArgs args)
    {
        UnwatchDocument(args.Document);
        Schedule(activate: false);
    }

    private void OnDocumentExecutionChanged(object? sender, EventArgs args)
    {
        // Command/Lisp end events can fire before CMDACTIVE has settled.
        // Requery on the next Idle, coalescing nested command notifications.
        Schedule(activate: false);
    }

    private void Schedule(bool activate)
    {
        _activate |= activate;
        if (_idleSubscribed) return;
        AcadApp.Idle += OnIdle;
        _idleSubscribed = true;
    }

    private void UnsubscribeIdle()
    {
        if (!_idleSubscribed) return;
        AcadApp.Idle -= OnIdle;
        _idleSubscribed = false;
    }

    private void OnIdle(object? sender, EventArgs args)
    {
        bool waitingForRibbon = false;
        try
        {
            var ribbon = ComponentManager.Ribbon;
            if (ribbon is null)
            {
                waitingForRibbon = true;
                return; // Ribbon may not exist yet at NETLOAD/startup.
            }
            _updating = true;
            var tab = ribbon.Tabs.FirstOrDefault(item => item.Id == TabId);
            if (tab is null)
            {
                tab = new RibbonTab { Id = TabId, Title = "BotaHelp" };
                tab.Panels.Add(CreatePanel("Preferencias", CommandCatalog.Settings));
                tab.Panels.Add(CreatePanel("Manobra Bota", CommandCatalog.Maneuvers));
                tab.Panels.Add(CreatePanel("Manobras", CommandCatalog.Connections));
                ribbon.Tabs.Add(tab);
            }
            if (_activate) tab.IsActive = true;
            _activate = false;
            BotaCommands.PreloadCurrentDocument();
        }
        catch (System.Exception error)
        {
            Write($"Nao foi possivel criar a aba: {error.Message}. Use BOTAHELP para tentar novamente.");
        }
        finally
        {
            _updating = false;
            if (!waitingForRibbon)
            {
                UnsubscribeIdle();
                // AutoCAD execution changes do not automatically notify WPF.
                // Refresh all buttons after normal completion, Esc or errors.
                CommandManager.InvalidateRequerySuggested();
            }
        }
    }

    private static RibbonPanel CreatePanel(string title, IEnumerable<ButtonSpec> specs)
    {
        var source = new RibbonPanelSource { Title = title };
        foreach (ButtonSpec spec in specs)
        {
            var image = IconFactory.Create(spec.Icon);
            source.Items.Add(new RibbonButton
            {
                Id = "BOTAHELP_" + spec.Command,
                Text = spec.Label,
                ShowText = true,
                ShowImage = true,
                Size = RibbonItemSize.Large,
                Orientation = System.Windows.Controls.Orientation.Vertical,
                Image = image,
                LargeImage = image,
                ToolTip = spec.Description + "\nComando: " + spec.Command,
                CommandParameter = spec.Command,
                CommandHandler = new BotaButtonHandler(),
            });
        }
        return new RibbonPanel { Source = source };
    }

    private static void Write(string message) => AcadApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\n" + message + "\n");

    private sealed class BotaButtonHandler : ICommand
    {
        public event EventHandler? CanExecuteChanged
        {
            add => CommandManager.RequerySuggested += value;
            remove => CommandManager.RequerySuggested -= value;
        }

        public bool CanExecute(object? parameter)
        {
            // WPF can query this while AutoCAD is starting or closing a drawing.
            try
            {
                return AcadApp.DocumentManager.MdiActiveDocument is not null
                    && Convert.ToInt32(AcadApp.GetSystemVariable("CMDACTIVE")) == 0;
            }
            catch (System.Exception) { return false; }
        }

        public void Execute(object? parameter)
        {
            string? command = parameter as string;
            if (parameter is RibbonButton button) command = button.CommandParameter as string;
            try
            {
                if (command is not null && CommandCatalog.IsAllowed(command)) BotaCommands.RunFromRibbon(command);
            }
            catch (System.Exception error)
            {
                Write($"Nao foi possivel iniciar o comando: {error.Message}");
            }
        }
    }
}
