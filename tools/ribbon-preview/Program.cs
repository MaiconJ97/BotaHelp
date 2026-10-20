using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using BotaHelp;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        if (args.Length != 1) throw new ArgumentException("Expected the output PNG path.");
        var specs = CommandCatalog.Maneuvers.OrderBy(spec => spec.Command == "BOTA3" ? 1 : 0)
            .Concat(CommandCatalog.Connections).Concat(CommandCatalog.Settings).ToArray();
        int width = specs.Length * 240;
        var visual = new DrawingVisual();
        using (DrawingContext dc = visual.RenderOpen())
        {
            for (int row = 0; row < 2; row++)
            {
                int y = row * 180;
                Brush surface = row == 0 ? new SolidColorBrush(Color.FromRgb(22, 29, 36)) : Brushes.WhiteSmoke;
                Brush text = row == 0 ? Brushes.WhiteSmoke : Brushes.DarkSlateGray;
                dc.DrawRectangle(surface, null, new Rect(0, y, width, 180));
                for (int column = 0; column < specs.Length; column++)
                {
                    int x = column * 240;
                    var icon = IconFactory.Create(specs[column].Icon);
                    Label(dc, specs[column].Label, new Point(x + 28, y + 18), text, 15);
                    dc.DrawImage(icon, new Rect(x + 28, y + 55, 96, 96));
                    dc.DrawImage(icon, new Rect(x + 166, y + 83, 32, 32));
                    Label(dc, "32 px", new Point(x + 166, y + 123), text, 10);
                }
            }
        }
        var bitmap = new RenderTargetBitmap(width, 360, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(visual);
        Save(bitmap, args[0]);
        foreach (var spec in specs)
        {
            var iconVisual = new DrawingVisual();
            using (var dc = iconVisual.RenderOpen())
                dc.DrawImage(IconFactory.Create(spec.Icon), new Rect(0, 0, 128, 128));
            var transparent = new RenderTargetBitmap(128, 128, 96, 96, PixelFormats.Pbgra32);
            transparent.Render(iconVisual);
            var pixels = new byte[128 * 128 * 4];
            transparent.CopyPixels(pixels, 128 * 4, 0);
            foreach (int pixel in new[] { 0, 127, 127 * 128, 128 * 128 - 1 })
                if (pixels[pixel * 4 + 3] != 0) throw new InvalidOperationException("Icon background is not transparent: " + spec.Command);
            string iconPath = Path.Combine(Path.GetDirectoryName(Path.GetFullPath(args[0]))!,
                Path.GetFileNameWithoutExtension(args[0]) + "-" + spec.Command + ".png");
            Save(transparent, iconPath);
        }
    }

    private static void Save(BitmapSource bitmap, string path)
    {
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var file = File.Create(path);
        encoder.Save(file);
        Console.WriteLine(Path.GetFullPath(path));
    }

    private static void Label(DrawingContext dc, string text, Point position, Brush brush, int size)
    {
        dc.DrawText(new FormattedText(text, CultureInfo.InvariantCulture, FlowDirection.LeftToRight,
            new Typeface("Segoe UI"), size, brush, 1.0), position);
    }
}
