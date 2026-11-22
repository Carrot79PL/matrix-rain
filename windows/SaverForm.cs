using System.Runtime.InteropServices;

namespace MatrixRain;

/// <summary>Okno wygaszacza: pełnoekranowe na monitorze (/s) albo dziecko okna podglądu (/p).</summary>
public sealed class SaverForm : Form
{
    [DllImport("user32.dll")] static extern IntPtr SetParent(IntPtr child, IntPtr parent);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int idx, int val);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int idx);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }

    readonly bool preview;
    readonly IntPtr parent;
    readonly Screen screen;
    Renderer rend;
    readonly System.Windows.Forms.Timer timer = new() { Interval = 1 };
    Point? start; int ticks;
    public List<SaverForm> Peers;

    public SaverForm(Screen s, IntPtr parentHwnd)
    {
        screen = s; parent = parentHwnd; preview = parentHwnd != IntPtr.Zero;
        FormBorderStyle = FormBorderStyle.None; BackColor = System.Drawing.Color.Black;
        StartPosition = FormStartPosition.Manual; ShowInTaskbar = false;
        if (preview)
        {
            GetClientRect(parent, out var r);
            Bounds = new System.Drawing.Rectangle(0, 0, r.R - r.L, r.B - r.T);
        }
        else
        {
            Bounds = s.Bounds; TopMost = true;
#if !DEBUG
            Cursor.Hide();
#endif
        }
        timer.Tick += (_, _) => Frame();
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        if (preview)
        {
            SetParent(Handle, parent);
            SetWindowLong(Handle, -16, GetWindowLong(Handle, -16) | 0x40000000);   // WS_CHILD
        }
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        try
        {
            var set = Settings.Load();
            rend = new Renderer(Handle, ClientSize.Width, ClientSize.Height, set)
            {
                Scale = Math.Max(1f, DeviceDpi / 96f), SizeFactor = preview ? 0.5f : 1f
            };
            timer.Start();
        }
        catch (Exception ex)
        {
            try { File.WriteAllText(Path.Combine(Path.GetTempPath(), "MatrixRain-error.txt"), ex.ToString()); } catch { }
        }
    }

    void Frame()
    {
        if (rend == null) return;
        if (!preview) { ClientSize = screen.Bounds.Size; }
        rend.Resize(ClientSize.Width, ClientSize.Height);
        rend.Render();
        ticks++;
    }

    void Quit()
    {
        if (preview) return;
        timer.Stop();
        var list = Peers ?? new List<SaverForm> { this };
        foreach (var f in list.ToList()) f.Close();
    }

    protected override void OnKeyDown(KeyEventArgs e) { base.OnKeyDown(e); Quit(); }
    protected override void OnMouseDown(MouseEventArgs e) { base.OnMouseDown(e); Quit(); }
    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        if (preview) return;
        if (start == null) { start = e.Location; return; }
        if (Math.Abs(e.X - start.Value.X) + Math.Abs(e.Y - start.Value.Y) > 12) Quit();
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        timer.Stop(); rend?.Dispose(); rend = null;
        base.OnFormClosed(e);
    }

    protected override CreateParams CreateParams
    {
        get { var cp = base.CreateParams; if (preview) cp.Style |= 0x40000000; return cp; }
    }
}
