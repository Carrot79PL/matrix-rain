using System.Text.Json;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

namespace MatrixRain;

/// <summary>Ustawienia zapisane w %APPDATA%\MatrixRain\settings.json (te same klucze co wersja macOS).</summary>
public sealed class Settings
{
    public static readonly string Dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MatrixRain");
    public static readonly string ImagesDir = Path.Combine(Dir, "images");
    static readonly string FilePath = Path.Combine(Dir, "settings.json");

    public static readonly (string Pl, string En, float[] Dark, float[] Bright)[] Themes =
    {
        ("Zielony klasyczny", "Classic green", new[]{0.00f,0.22f,0.05f,1f}, new[]{0.10f,1.00f,0.30f,1f}),
        ("Czerwona pigułka", "Red pill",       new[]{0.28f,0.02f,0.02f,1f}, new[]{1.00f,0.12f,0.10f,1f}),
        ("Niebieska pigułka", "Blue pill",     new[]{0.00f,0.12f,0.28f,1f}, new[]{0.15f,0.65f,1.00f,1f}),
        ("Złoto", "Gold",                      new[]{0.26f,0.15f,0.00f,1f}, new[]{1.00f,0.74f,0.15f,1f}),
        ("Fiolet", "Violet",                   new[]{0.15f,0.02f,0.25f,1f}, new[]{0.75f,0.30f,1.00f,1f}),
        ("Biały / mono", "White / mono",       new[]{0.14f,0.15f,0.17f,1f}, new[]{0.88f,0.95f,1.00f,1f}),
    };

    public Dictionary<string, double> V = new();

    static Dictionary<string, double> Defaults() => new()
    {
        ["streams"] = 3.4, ["speed"] = 1, ["size"] = 18, ["glow"] = 1, ["bright"] = 1, ["glitch"] = 0.2,
        ["imgMix"] = 0.9, ["period"] = 25, ["mode"] = 0, ["theme"] = 0, ["photoColor"] = 0,
        ["curve"] = 0.35, ["scan"] = 0.35, ["mask"] = 0.35, ["roll"] = 0.35, ["grain"] = 0.5, ["vignette"] = 0.5,
        ["zoom"] = 0, ["zoomPeriod"] = 40, ["wet"] = 0, ["ghost"] = 0, ["wave"] = 0, ["depth"] = 0,
        ["alarm"] = 0, ["dissolve"] = 0, ["audio"] = 0,
        ["lang"] = System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "pl" ? 0 : 1,
    };

    public double this[string k] { get => V.TryGetValue(k, out var x) ? x : 0; set => V[k] = value; }
    public float F(string k) => (float)this[k];
    public int I(string k) => (int)Math.Round(this[k]);

    public static Settings Load()
    {
        var s = new Settings { V = Defaults() };
        try
        {
            if (File.Exists(FilePath))
            {
                var d = JsonSerializer.Deserialize<Dictionary<string, double>>(File.ReadAllText(FilePath));
                if (d != null) foreach (var kv in d) s.V[kv.Key] = kv.Value;
            }
        }
        catch { }
        return s;
    }

    public void Save()
    {
        try { Directory.CreateDirectory(Dir); File.WriteAllText(FilePath, JsonSerializer.Serialize(V)); } catch { }
    }

    public static int PhotoCount() => Directory.Exists(ImagesDir) ? Directory.GetFiles(ImagesDir, "*.jpg").Length : 0;

    /// <summary>Kopiuje wybrane zdjęcia jako miniatury 640x400 (kadrowanie "cover"), max 12.</summary>
    public static void ImportPhotos(IEnumerable<string> paths)
    {
        Directory.CreateDirectory(ImagesDir);
        foreach (var f in Directory.GetFiles(ImagesDir, "*.jpg")) { try { File.Delete(f); } catch { } }
        int n = 0;
        foreach (var p in paths)
        {
            if (n >= 12) break;
            try
            {
                using var src = Image.FromFile(p);
                using var bmp = new Bitmap(640, 400, PixelFormat.Format32bppArgb);
                using (var g = Graphics.FromImage(bmp))
                {
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    float sc = Math.Max(640f / src.Width, 400f / src.Height);
                    float w = src.Width * sc, h = src.Height * sc;
                    g.DrawImage(src, (640 - w) / 2, (400 - h) / 2, w, h);
                }
                bmp.Save(Path.Combine(ImagesDir, $"p{n:D2}.jpg"), ImageFormat.Jpeg);
                n++;
            }
            catch { }
        }
    }
}
