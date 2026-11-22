using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Numerics;
using System.Reflection;
using System.Runtime.InteropServices;
using Vortice.D3DCompiler;
using Vortice.Direct3D;
using Vortice.Direct3D11;
using Vortice.DXGI;


namespace MatrixRain;

[StructLayout(LayoutKind.Sequential)]
struct Uniforms   // musi odpowiadać struct UT w shader.hlsl (32 floaty + 2 x float4)
{
    public Vector2 res; public float cell, time;
    public float streams, speed, bright, glow;
    public float nGlyph, gap, imgMix, imgT;
    public float imgColor, imgLod, glitch, imgAsp;
    public float mirror, camera, p1, p2;
    public float scan, mask, roll, grain;
    public float cell0, wet, ghostK, wave;
    public float depth, noise, dissolve, audio;
    public Vector4 tintDark, tintBright;
}

/// <summary>Renderer Direct3D 11: scena (deszcz, 1-3 warstwy, duchy) -> mipmapy -> kompozyt (bloom, CRT, winieta...).</summary>
public sealed class Renderer : IDisposable
{
    readonly Settings S;
    readonly ID3D11Device dev;
    readonly ID3D11DeviceContext ctx;
    readonly IDXGISwapChain1 swap;
    ID3D11RenderTargetView backRtv;
    readonly ID3D11VertexShader vs;
    readonly ID3D11PixelShader psScene, psComp;
    readonly ID3D11Buffer cbuf;
    readonly ID3D11SamplerState sampler;
    readonly ID3D11RasterizerState raster;
    ID3D11ShaderResourceView atlasSrv;
    readonly ID3D11ShaderResourceView dummySrv;
    readonly List<ID3D11ShaderResourceView> photos = new();
    ID3D11ShaderResourceView clockSrv; string clockStamp = "";
    readonly ID3D11Texture2D[] sceneTex = new ID3D11Texture2D[2];
    readonly ID3D11ShaderResourceView[] sceneSrv = new ID3D11ShaderResourceView[2];
    readonly ID3D11RenderTargetView[] sceneRtv = new ID3D11RenderTargetView[2];
    int sceneW, sceneH, sceneIdx; bool histValid;
    int width, height;
    float nGlyph = 1;
    readonly Stopwatch clock = Stopwatch.StartNew();
    double lastReload;
    int photoSig = -1;
    Audio audio;

    public float Scale = 1f;       // skala DPI
    public float SizeFactor = 1f;  // 0.5 w podglądzie

    public Renderer(IntPtr hwnd, int w, int h, Settings settings)
    {
        S = settings; width = Math.Max(1, w); height = Math.Max(1, h);
        D3D11.D3D11CreateDevice(null, DriverType.Hardware, DeviceCreationFlags.BgraSupport,
            new[] { FeatureLevel.Level_11_0, FeatureLevel.Level_10_1, FeatureLevel.Level_10_0 }, out dev, out ctx).CheckError();
        using var factory = DXGI.CreateDXGIFactory1<IDXGIFactory2>();
        var sd = new SwapChainDescription1
        {
            Width = (uint)width, Height = (uint)height, Format = Format.B8G8R8A8_UNorm,
            BufferUsage = Usage.RenderTargetOutput, BufferCount = 2,
            SampleDescription = new SampleDescription(1, 0), SwapEffect = SwapEffect.FlipDiscard,
            Scaling = Scaling.Stretch, AlphaMode = AlphaMode.Ignore
        };
        swap = factory.CreateSwapChainForHwnd(dev, hwnd, sd);
        factory.MakeWindowAssociation(hwnd, WindowAssociationFlags.IgnoreAll);
        MakeBackRtv();

        string src = ReadResource("shader.hlsl");
        var vsBlob = Compile(src, "vs", "vs_5_0");
        var psS = Compile(src, "scene", "ps_5_0");
        var psC = Compile(src, "comp", "ps_5_0");
        vs = dev.CreateVertexShader(vsBlob);
        psScene = dev.CreatePixelShader(psS);
        psComp = dev.CreatePixelShader(psC);
        cbuf = dev.CreateBuffer(new BufferDescription((uint)Marshal.SizeOf<Uniforms>(), BindFlags.ConstantBuffer, ResourceUsage.Default));
        sampler = dev.CreateSamplerState(new SamplerDescription(Filter.MinMagMipLinear, TextureAddressMode.Clamp, TextureAddressMode.Clamp, TextureAddressMode.Clamp));
        raster = dev.CreateRasterizerState(new RasterizerDescription(CullMode.None, Vortice.Direct3D11.FillMode.Solid) { DepthClipEnable = false });
        dummySrv = MakeTexture(new byte[] { 0, 0, 0, 255 }, 1, 1, Format.B8G8R8A8_UNorm, false);
        Log.W("shaders compiled");
        BuildAtlas();
        Log.W("atlas built, glyphs=" + nGlyph);
        S.V = Settings.Load().V;
    }

    static byte[] Compile(string src, string entry, string profile)
    {
        var r = Compiler.Compile(src, null, null, entry, "shader.hlsl", profile, ShaderFlags.OptimizationLevel3, EffectFlags.None, out var code, out var err);
        if (r.Failure || code == null)
            throw new Exception("HLSL " + entry + ": " + (err != null ? System.Text.Encoding.UTF8.GetString(err.AsBytes()) : r.ToString()));
        var bytes = code.AsBytes();
        code.Dispose(); err?.Dispose();
        return bytes;
    }

    static string ReadResource(string name)
    {
        using var s = Assembly.GetExecutingAssembly().GetManifestResourceStream(name);
        if (s == null) throw new Exception("Brak zasobu " + name);
        using var r = new StreamReader(s);
        return r.ReadToEnd();
    }

    void MakeBackRtv()
    {
        backRtv?.Dispose();
        using var bb = swap.GetBuffer<ID3D11Texture2D>(0);
        backRtv = dev.CreateRenderTargetView(bb);
    }

    public void Resize(int w, int h)
    {
        w = Math.Max(1, w); h = Math.Max(1, h);
        if (w == width && h == height) return;
        width = w; height = h;
        ctx.OMSetRenderTargets((ID3D11RenderTargetView)null);
        backRtv?.Dispose(); backRtv = null;
        swap.ResizeBuffers(0, (uint)w, (uint)h, Format.Unknown, SwapChainFlags.None);
        MakeBackRtv();
    }

    // ---------- tekstury ----------

    ID3D11ShaderResourceView MakeTexture(byte[] data, int w, int h, Format fmt, bool mips)
    {
        var desc = new Texture2DDescription
        {
            Width = (uint)w, Height = (uint)h, MipLevels = mips ? 0u : 1u, ArraySize = 1, Format = fmt,
            SampleDescription = new SampleDescription(1, 0), Usage = ResourceUsage.Default,
            BindFlags = mips ? (BindFlags.ShaderResource | BindFlags.RenderTarget) : BindFlags.ShaderResource,
            MiscFlags = mips ? ResourceOptionFlags.GenerateMips : ResourceOptionFlags.None
        };
        var tex = dev.CreateTexture2D(desc);
        uint bpp = fmt == Format.R8_UNorm ? 1u : 4u;
        GCHandle hnd = GCHandle.Alloc(data, GCHandleType.Pinned);
        try { ctx.UpdateSubresource(tex, 0, null, hnd.AddrOfPinnedObject(), (uint)w * bpp, 0); }
        finally { hnd.Free(); }
        var srv = dev.CreateShaderResourceView(tex);
        if (mips) ctx.GenerateMips(srv);
        tex.Dispose();   // SRV trzyma zasób
        return srv;
    }

    ID3D11ShaderResourceView FromBitmap(Bitmap bmp)
    {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var bd = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var bytes = new byte[bd.Stride * bd.Height];
        Marshal.Copy(bd.Scan0, bytes, 0, bytes.Length);
        bmp.UnlockBits(bd);
        return MakeTexture(bytes, bmp.Width, bmp.Height, Format.B8G8R8A8_UNorm, true);
    }

    void RebuildPhotos()
    {
        foreach (var p in photos) p.Dispose();
        photos.Clear();
        if (!Directory.Exists(Settings.ImagesDir)) return;
        foreach (var f in Directory.GetFiles(Settings.ImagesDir, "*.jpg").OrderBy(x => x))
        {
            try { using var b = new Bitmap(f); using var c = new Bitmap(b); photos.Add(FromBitmap(c)); } catch { }
        }
    }

    void UpdateClock()
    {
        string stamp = DateTime.Now.ToString("HH:mm");
        if (stamp == clockStamp && clockSrv != null) return;
        clockStamp = stamp;
        using var bmp = new Bitmap(640, 400, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.Black);
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            float size = 260;
            using var f0 = new Font("Segoe UI", size, FontStyle.Bold, GraphicsUnit.Pixel);
            var m = g.MeasureString(stamp, f0, 4000, StringFormat.GenericTypographic);
            if (m.Width > 560) size = size * 560 / m.Width;
            using var f = new Font("Segoe UI", size, FontStyle.Bold, GraphicsUnit.Pixel);
            var sz = g.MeasureString(stamp, f, 4000, StringFormat.GenericTypographic);
            g.DrawString(stamp, f, Brushes.White, (640 - sz.Width) / 2, (400 - sz.Height) / 2, StringFormat.GenericTypographic);
        }
        clockSrv?.Dispose();
        clockSrv = FromBitmap(bmp);
    }

    // ---------- atlas glifów (8x8 komórek po 128 px, jak w wersji macOS) ----------

    static readonly int[] GlyphCodes = {
        0x30a2,0x30a3,0x30a4,0x30a6,0x30a8,0x30aa,0x30ab,0x30ad,0x30b1,0x30b3,0x30b5,0x30b7,0x30b9,0x30bb,0x30bd,0x30bf,0x30c4,0x30c6,
        0x30ca,0x30cb,0x30cc,0x30cd,0x30cf,0x30d2,0x30db,0x30de,0x30df,0x30e0,0x30e1,0x30e2,0x30e4,0x30e8,0x30e9,0x30ea,0x30ef,0x30fc,
        0x30,0x31,0x32,0x33,0x34,0x35,0x37,0x38,0x39,0x22,0x2a,0x2b,0x3a,0x3c,0x3e,0x7c,0xa6,0x254c,0x25aa,0x7a };

    void BuildAtlas()
    {
        const int size = 1024, cell = 128;
        FontFamily fam = null;
        var pfc = new PrivateFontCollection();
        try
        {
            using var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("Matrix-Code.ttf");
            if (s != null)
            {
                var data = new byte[s.Length]; s.ReadExactly(data, 0, data.Length);
                var p = Marshal.AllocCoTaskMem(data.Length);
                Marshal.Copy(data, 0, p, data.Length);
                pfc.AddMemoryFont(p, data.Length);
                fam = pfc.Families[0];
            }
        }
        catch { fam = null; }
        // zapasowa czcionka z katakaną, gdy brak Matrix-Code.ttf
        int[] codes = GlyphCodes;
        if (fam == null)
        {
            fam = new FontFamily("Yu Gothic UI");
            codes = Enumerable.Range(0x30A1, 0x56).Concat(Enumerable.Range(0x30, 10)).Take(64).ToArray();
        }
        nGlyph = Math.Min(64, codes.Length);
        var atlas = new byte[size * size];
        using var font = new Font(fam, 80, FontStyle.Regular, GraphicsUnit.Pixel);
        using var tmp = new Bitmap(256, 256, PixelFormat.Format32bppArgb);
        for (int i = 0; i < (int)nGlyph; i++)
        {
            using (var g = Graphics.FromImage(tmp))
            {
                g.Clear(Color.Black);
                g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
                g.DrawString(char.ConvertFromUtf32(codes[i]), font, Brushes.White, 40, 40, StringFormat.GenericTypographic);
            }
            var bd = tmp.LockBits(new Rectangle(0, 0, 256, 256), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var px = new byte[bd.Stride * 256];
            Marshal.Copy(bd.Scan0, px, 0, px.Length);
            tmp.UnlockBits(bd);
            int minX = 256, minY = 256, maxX = -1, maxY = -1;
            for (int y = 0; y < 256; y++)
                for (int x = 0; x < 256; x++)
                    if (px[y * bd.Stride + x * 4 + 1] > 24) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
            if (maxX < 0) continue;
            int gw = maxX - minX + 1, gh = maxY - minY + 1;
            int ox = (i % 8) * cell + (cell - gw) / 2, oy = (i / 8) * cell + (cell - gh) / 2;
            for (int y = 0; y < gh; y++)
                for (int x = 0; x < gw; x++)
                {
                    int ax = ox + x, ay = oy + y;
                    if (ax >= 0 && ax < size && ay >= 0 && ay < size) atlas[ay * size + ax] = px[(minY + y) * bd.Stride + (minX + x) * 4 + 1];
                }
        }
        atlasSrv = MakeTexture(atlas, size, size, Format.R8_UNorm, true);
    }

    // ---------- scena ----------

    void EnsureScenes()
    {
        if (sceneTex[0] != null && sceneW == width && sceneH == height) return;
        for (int i = 0; i < 2; i++) { sceneRtv[i]?.Dispose(); sceneSrv[i]?.Dispose(); sceneTex[i]?.Dispose(); }
        var d = new Texture2DDescription
        {
            Width = (uint)width, Height = (uint)height, MipLevels = 0, ArraySize = 1, Format = Format.R16G16B16A16_Float,
            SampleDescription = new SampleDescription(1, 0), Usage = ResourceUsage.Default,
            BindFlags = BindFlags.RenderTarget | BindFlags.ShaderResource, MiscFlags = ResourceOptionFlags.GenerateMips
        };
        for (int i = 0; i < 2; i++)
        {
            sceneTex[i] = dev.CreateTexture2D(d);
            sceneRtv[i] = dev.CreateRenderTargetView(sceneTex[i]);
            sceneSrv[i] = dev.CreateShaderResourceView(sceneTex[i]);
        }
        sceneW = width; sceneH = height; histValid = false;
    }

    List<ID3D11ShaderResourceView> ImageItems(int mode)
    {
        var l = new List<ID3D11ShaderResourceView>();
        if (mode == 1 || mode == 3) l.AddRange(photos);
        if (mode == 2 || mode == 3) { UpdateClock(); if (clockSrv != null) l.Add(clockSrv); }
        return l;
    }

    public void Render()
    {
        float time = (float)clock.Elapsed.TotalSeconds;
        if (time - lastReload > 1.0)
        {
            lastReload = time;
            S.V = Settings.Load().V;
            int sig = Settings.PhotoCount() * 1000 + (Directory.Exists(Settings.ImagesDir) ? (int)(Directory.GetLastWriteTimeUtc(Settings.ImagesDir).Ticks / 10000000 % 1000) : 0);
            if (sig != photoSig) { photoSig = sig; RebuildPhotos(); }
        }
        EnsureScenes();

        float audioSens = S.F("audio");
        if (audioSens > 0.001) { audio ??= new Audio(); }
        else if (audio != null) { audio.Dispose(); audio = null; }
        float audioK = audioSens > 0.001 ? Math.Min(1, (audio?.Level ?? 0) * audioSens * 1.5f) : 0;

        int mode = Math.Clamp(S.I("mode"), 0, 3);
        float streams = S.F("streams"), ghost = S.F("ghost"), zoomAmt = S.F("zoom"), zoomPeriod = Math.Max(5, S.F("zoomPeriod"));
        float period = Math.Max(3, S.F("period"));
        var items = ImageItems(mode);
        ID3D11ShaderResourceView texA = dummySrv, texB = dummySrv;
        float imgT = 0, mix = 0, asp = 1.6f;
        if (items.Count > 0)
        {
            float x = time / period; int slot = (int)Math.Floor(x);
            texA = items[slot % items.Count]; texB = items[(slot + 1) % items.Count];
            if (items.Count > 1)
            {
                float ph = x - slot, k = Math.Clamp((ph - 0.85f) / 0.15f, 0, 1);
                imgT = k * k * (3 - 2 * k);
            }
            else texB = texA;
            mix = S.F("imgMix"); asp = 640f / 400f;
        }
        float sizePts = S.F("size") * SizeFactor;
        float cell0 = Math.Max(5, sizePts * Scale);
        float zf = zoomAmt > 0.001f ? MathF.Pow(2, zoomAmt * 1.3f * MathF.Sin(2 * MathF.PI * time / zoomPeriod)) : 1;
        float cell = Math.Max(4, cell0 * zf);
        float cols = width / cell;
        float lod = Math.Max(0, MathF.Log2(640f / Math.Max(cols, 1)));
        var th = Settings.Themes[Math.Clamp(S.I("theme"), 0, Settings.Themes.Length - 1)];
        var tDark = new Vector4(th.Dark[0], th.Dark[1], th.Dark[2], 1);
        var tBright = new Vector4(th.Bright[0], th.Bright[1], th.Bright[2], 1);
        int alarm = S.I("alarm");
        if (alarm > 0)
        {
            int interval = new[] { 60, 60, 15, 5 }[Math.Min(alarm, 3)];
            var now = DateTime.Now;
            double secs = (now.Minute % interval) * 60 + now.Second;
            if (secs < 12)
            {
                float k = (float)Math.Sin(Math.PI * secs / 12);
                tDark += (new Vector4(0.28f, 0.02f, 0.02f, 1) - tDark) * k;
                tBright += (new Vector4(1f, 0.12f, 0.10f, 1) - tBright) * k;
            }
        }
        var u = new Uniforms
        {
            res = new Vector2(width, height), cell = cell, time = time, streams = streams, speed = S.F("speed"),
            bright = S.F("bright"), glow = S.F("glow"), nGlyph = nGlyph, gap = Math.Max(0, 1 - streams / 4) * 0.8f,
            imgMix = mix, imgT = imgT, imgColor = S.I("photoColor") == 1 ? 1 : 0, imgLod = lod, glitch = S.F("glitch"),
            imgAsp = asp, mirror = 0, camera = 0, p1 = S.F("curve"), p2 = S.F("vignette"), scan = S.F("scan"),
            mask = S.F("mask"), roll = S.F("roll"), grain = S.F("grain"), cell0 = cell0, wet = S.F("wet"),
            ghostK = ghost > 0.001f ? 0.80f + 0.17f * ghost : 0, wave = S.F("wave"), depth = S.F("depth"), noise = 0,
            dissolve = S.F("dissolve"), audio = audioK, tintDark = tDark, tintBright = tBright
        };
        ctx.UpdateSubresource(in u, cbuf);

        ctx.IASetPrimitiveTopology(PrimitiveTopology.TriangleList);
        ctx.VSSetShader(vs);
        ctx.RSSetState(raster);
        ctx.PSSetConstantBuffer(0, cbuf);
        ctx.PSSetSamplers(0, new[] { sampler });

        // pass 1: scena
        int cur = sceneIdx;
        var hist = (ghost > 0.001f && histValid) ? sceneSrv[1 - cur] : dummySrv;
        ctx.OMSetRenderTargets(sceneRtv[cur]);
        ctx.RSSetViewport(0, 0, width, height);
        ctx.PSSetShader(psScene);
        ctx.PSSetShaderResources(0, new[] { atlasSrv, texA, texB, hist });
        ctx.Draw(3, 0);
        ctx.OMSetRenderTargets((ID3D11RenderTargetView)null);
        ctx.PSSetShaderResources(0, new ID3D11ShaderResourceView[] { null, null, null, null, null });
        ctx.GenerateMips(sceneSrv[cur]);

        // pass 2: kompozyt na ekran
        ctx.OMSetRenderTargets(backRtv);
        ctx.RSSetViewport(0, 0, width, height);
        ctx.PSSetShader(psComp);
        ctx.PSSetShaderResources(4, new[] { sceneSrv[cur] });
        ctx.Draw(3, 0);
        ctx.PSSetShaderResources(4, new ID3D11ShaderResourceView[] { null });
        ctx.OMSetRenderTargets((ID3D11RenderTargetView)null);

        sceneIdx = 1 - cur; histValid = true;
        swap.Present(1, PresentFlags.None);
    }

    public void Dispose()
    {
        audio?.Dispose();
        foreach (var p in photos) p.Dispose();
        clockSrv?.Dispose(); atlasSrv?.Dispose(); dummySrv?.Dispose();
        for (int i = 0; i < 2; i++) { sceneRtv[i]?.Dispose(); sceneSrv[i]?.Dispose(); sceneTex[i]?.Dispose(); }
        backRtv?.Dispose(); cbuf?.Dispose(); sampler?.Dispose(); raster?.Dispose();
        vs?.Dispose(); psScene?.Dispose(); psComp?.Dispose();
        swap?.Dispose(); ctx?.Dispose(); dev?.Dispose();
    }
}

/// <summary>Poziom dźwięku z mikrofonu (NAudio WASAPI); gdy niedostępny - zawsze 0.</summary>
sealed class Audio : IDisposable
{
    NAudio.Wave.WaveInEvent wi;
    public volatile float Level;
    public Audio()
    {
        try
        {
            wi = new NAudio.Wave.WaveInEvent { WaveFormat = new NAudio.Wave.WaveFormat(16000, 16, 1), BufferMilliseconds = 50 };
            wi.DataAvailable += (s, e) =>
            {
                double sum = 0; int n = e.BytesRecorded / 2;
                for (int i = 0; i < n; i++) { short v = BitConverter.ToInt16(e.Buffer, i * 2); sum += v * (double)v; }
                float rms = n > 0 ? (float)Math.Sqrt(sum / n) / 32768f : 0;
                Level = Level * 0.7f + Math.Min(1, rms * 6) * 0.3f;
            };
            wi.StartRecording();
        }
        catch { wi = null; }
    }
    public void Dispose() { try { wi?.StopRecording(); wi?.Dispose(); } catch { } }
}
