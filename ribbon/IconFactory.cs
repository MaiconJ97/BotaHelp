using System.Globalization;
using System.Windows;
using System.Windows.Media;

namespace BotaHelp;

internal static class IconFactory
{
    internal static DrawingImage Create(string kind)
    {
        var group = new DrawingGroup();
        using (DrawingContext dc = group.Open())
        {
            dc.DrawRectangle(Brushes.Transparent, null, new Rect(0, 0, 32, 32));
            var yellow = new SolidColorBrush(Color.FromRgb(255, 241, 0));
            var orange = new SolidColorBrush(Color.FromRgb(255, 139, 0));
            if (kind.StartsWith("turn", StringComparison.Ordinal) || kind == "side")
            {
                DrawManeuver(dc, kind == "turn3");
            }
            else if (kind == "fillet")
            {
                dc.DrawGeometry(null, new Pen(yellow, 2.5), Geometry.Parse("M 4,3 L 4,15 C 4,23 9,28 17,28 L 29,28"));
                dc.DrawGeometry(null, new Pen(orange, 1.5), Geometry.Parse("M 10,3 L 10,15 C 10,20 13,22 18,22 L 29,22"));
            }
            else if (kind == "settings")
            {
                foreach (var (y, x) in new[] { (7.0, 10.0), (16.0, 23.0), (25.0, 15.0) })
                {
                    dc.DrawLine(new Pen(yellow, 2), new Point(3, y), new Point(29, y));
                    dc.DrawRoundedRectangle(orange, null, new Rect(x - 2, y - 4, 5, 8), 1, 1);
                }
            }
            else
            {
                dc.DrawEllipse(null, new Pen(yellow, 2), new Point(16, 16), 13, 13);
                DrawCenteredText(dc, "?", new Point(16, 16), orange, 22);
            }
        }
        var image = new DrawingImage(group);
        image.Freeze();
        return image;
    }

    private static void DrawManeuver(DrawingContext dc, bool withFillet)
    {
        // Transparent vector miniature matching the supplied maneuver references.
        // BOTA/BOTA2/BotaM share the circular turn; BOTA3 shows the return.
        var yellow = Stroke(Color.FromRgb(255, 241, 0), 1.05);
        var orange = Stroke(Color.FromRgb(255, 139, 0), 1.0);
        var red = Stroke(Color.FromRgb(255, 55, 45), 1.0);

        dc.PushClip(new RectangleGeometry(new Rect(0, 0, 32, 32), 2.5, 2.5));
        if (withFillet)
        {
            dc.DrawGeometry(null, orange, Geometry.Parse(
                "M 1,16.68 L 31,7.20"));
            dc.DrawGeometry(null, yellow, Geometry.Parse(
                "M 4.79,28.25 L 8.57,16.85 C 9.25,14.90 10.25,13.90 11.82,13.27 " +
                "L 20.39,10.61 A 3.95,3.95 0 0 1 24.76,16.76 " +
                "C 23.72,18.14 22.91,19.43 22.35,21.05 L 19.85,28.25"));
        }
        else
        {
            dc.DrawGeometry(null, orange, Geometry.Parse("M 1,16.10 L 31,6.60"));
            dc.DrawGeometry(null, red, Geometry.Parse("M 20.06,28.84 L 28.33,7.42"));
            dc.DrawGeometry(null, yellow, Geometry.Parse("M 1,16.10 L 20.00,10.08"));
            dc.DrawGeometry(null, yellow, Geometry.Parse(
                "M 1.45,28.90 L 5.30,17.60 C 6.10,15.10 7.20,14.20 9.20,13.50 L 20.00,10.08"));
            dc.DrawEllipse(null, yellow, new Point(21.37, 14.79), 4.85, 4.85);
        }
        dc.Pop();
    }

    private static Pen Stroke(Color color, double width) => new(new SolidColorBrush(color), width)
    {
        StartLineCap = PenLineCap.Round,
        EndLineCap = PenLineCap.Round,
        LineJoin = PenLineJoin.Round,
    };

    private static void DrawCenteredText(DrawingContext dc, string text, Point center, Brush color, double size)
    {
        var formatted = new FormattedText(text, CultureInfo.InvariantCulture, FlowDirection.LeftToRight,
            new Typeface("Segoe UI"), size, color, 1.0);
        // Center the visible glyph, excluding the font's baseline and side bearings.
        Geometry glyph = formatted.BuildGeometry(new Point(0, 0));
        Rect bounds = glyph.Bounds;
        dc.PushTransform(new TranslateTransform(
            center.X - (bounds.Left + bounds.Width / 2),
            center.Y - (bounds.Top + bounds.Height / 2)));
        dc.DrawGeometry(color, null, glyph);
        dc.Pop();
    }
}
