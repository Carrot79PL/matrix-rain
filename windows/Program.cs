using System.Runtime.InteropServices;

namespace MatrixRain;

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        ApplicationConfiguration.Initialize();
        try { File.Delete(Path.Combine(Path.GetTempPath(), "MatrixRain-log.txt")); } catch { }
        Log.W("start v1.1.1 args=" + string.Join(" ", args));
        string mode = "/s"; IntPtr parent = IntPtr.Zero;
        if (args.Length > 0)
        {
            string a = args[0].ToLowerInvariant().Trim();
            string rest = args.Length > 1 ? args[1] : "";
            if (a.Contains(':')) { var p = a.Split(':'); a = p[0]; rest = p[1]; }
            mode = a;
            if (long.TryParse(rest, out long h)) parent = new IntPtr(h);
        }
        else mode = "/c";   // uruchomienie dwuklikiem = ustawienia

        try
        {
            if (mode.StartsWith("/c")) Application.Run(new OptionsForm());
            else if (mode.StartsWith("/p")) { if (parent != IntPtr.Zero) Application.Run(new SaverForm(Screen.PrimaryScreen, parent)); }
            else
            {
                var forms = Screen.AllScreens.Select(s => new SaverForm(s, IntPtr.Zero)).ToList();
                foreach (var f in forms) f.Peers = forms;
                Application.Run(new MultiContext(forms));
            }
        }
        catch (Exception ex)
        {
            try { File.WriteAllText(Path.Combine(Path.GetTempPath(), "MatrixRain-error.txt"), ex.ToString()); } catch { }
            if (mode.StartsWith("/c")) MessageBox.Show(ex.ToString(), "Matrix Rain");
        }
    }
}

public static class Log
{
    static readonly string Path_ = Path.Combine(Path.GetTempPath(), "MatrixRain-log.txt");
    public static void W(string m) { try { File.AppendAllText(Path_, DateTime.Now.ToString("HH:mm:ss.fff ") + m + "\n"); } catch { } }
}

sealed class MultiContext : ApplicationContext
{
    public MultiContext(List<SaverForm> forms)
    {
        foreach (var f in forms) { f.FormClosed += (s, e) => { if (forms.All(x => x.IsDisposed)) ExitThread(); }; f.Show(); }
    }
}
