namespace MatrixRain;

/// <summary>Okno opcji (zakładki jak w wersji macOS), PL/EN.</summary>
public sealed class OptionsForm : Form
{
    const string Author = "Tomasz Marchewka", Version = "1.1", RepoUrl = "https://github.com/Carrot79PL/matrix-rain";
    readonly Settings S = Settings.Load();
    int lang;
    TabControl tabs;
    Label photoLabel;

    public OptionsForm()
    {
        lang = S.I("lang");
        Text = "Matrix Rain"; FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = false; MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen; ClientSize = new Size(520, 470);
        Font = new Font("Segoe UI", 9f);
        Build();
    }

    string T(string pl, string en) => lang == 0 ? pl : en;

    void Build()
    {
        Controls.Clear();
        int tabIdx = tabs?.SelectedIndex ?? 0;
        var langLbl = new Label { Text = T("Język", "Language"), Location = new Point(14, 14), AutoSize = true };
        var langBox = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Location = new Point(110, 10), Width = 140 };
        langBox.Items.AddRange(new object[] { "Polski", "English" });
        langBox.SelectedIndex = lang;
        langBox.SelectedIndexChanged += (_, _) => { lang = langBox.SelectedIndex; S["lang"] = lang; Build(); };
        Controls.AddRange(new Control[] { langLbl, langBox });

        tabs = new TabControl { Location = new Point(10, 44), Size = new Size(500, 370) };
        Controls.Add(tabs);

        Tab(T("Wygląd", "Look"), (p, y) => {
            Combo(p, ref y, T("Motyw kolorów", "Color theme"), "theme", Settings.Themes.Select(t => lang == 0 ? t.Pl : t.En).ToArray());
            Slider(p, ref y, T("Rozmiar znaków", "Glyph size"), "size", 10, 40);
            Slider(p, ref y, T("Jasność", "Brightness"), "bright", 0.4, 1.6);
            Slider(p, ref y, T("Poświata", "Glow"), "glow", 0, 2);
            Slider(p, ref y, T("Winieta", "Vignette"), "vignette", 0, 1);
        });
        Tab(T("Ruch", "Motion"), (p, y) => {
            Slider(p, ref y, T("Gęstość", "Density"), "streams", 1, 4);
            Slider(p, ref y, T("Prędkość", "Speed"), "speed", 0.3, 2.5);
            Slider(p, ref y, "Glitch", "glitch", 0, 1);
            Slider(p, ref y, T("Auto-zoom znaków", "Auto-zoom of glyphs"), "zoom", 0, 1);
            Slider(p, ref y, T("Cykl zoomu (s)", "Zoom cycle (s)"), "zoomPeriod", 10, 120);
        });
        Tab(T("Efekty", "Effects"), (p, y) => {
            Slider(p, ref y, T("Mokra szyba", "Wet glass"), "wet", 0, 1);
            Slider(p, ref y, T("Duchy znaków", "Ghost trails"), "ghost", 0, 1);
            Slider(p, ref y, T("Fala jasności", "Brightness wave"), "wave", 0, 1);
            Slider(p, ref y, T("Głębia 3D", "3D depth"), "depth", 0, 1);
            Slider(p, ref y, T("Reakcja na dźwięk", "Sound reaction"), "audio", 0, 1);
            Combo(p, ref y, T("Czerwony alarm", "Red alert"), "alarm",
                new[] { T("Wyłączony", "Off"), T("Co godzinę", "Every hour"), T("Co 15 min", "Every 15 min"), T("Co 5 min", "Every 5 min") });
        });
        Tab(T("Ekran CRT", "CRT"), (p, y) => {
            Slider(p, ref y, T("Wygięcie ekranu", "Screen curvature"), "curve", 0, 1);
            Slider(p, ref y, T("Linie skanowania", "Scanlines"), "scan", 0, 1);
            Slider(p, ref y, T("Maska RGB", "RGB mask"), "mask", 0, 1);
            Slider(p, ref y, T("Pasmo odświeżania", "Refresh band"), "roll", 0, 1);
            Slider(p, ref y, T("Ziarno", "Film grain"), "grain", 0, 1);
        });
        Tab(T("Obraz", "Image"), (p, y) => {
            Combo(p, ref y, T("Obraz z kodu", "Image from code"), "mode",
                new[] { T("Tylko deszcz", "Rain only"), T("Zdjęcia", "Photos"), T("Zegar", "Clock"), T("Zdjęcia i zegar", "Photos & clock") });
            Combo(p, ref y, T("Kolor obrazu", "Image color"), "photoColor", new[] { T("Kolor motywu", "Theme color"), T("Kolory zdjęcia", "Photo colors") });
            Combo(p, ref y, T("Przejście obrazu", "Image transition"), "dissolve", new[] { T("Płynne", "Fade"), T("Rozpad na znaki", "Dissolve into glyphs") });
            Slider(p, ref y, T("Widoczność obrazu", "Image strength"), "imgMix", 0.2, 1);
            Slider(p, ref y, T("Zmiana obrazu (s)", "Image change (s)"), "period", 5, 60);
            var choose = new Button { Text = T("Wybierz zdjęcia…", "Choose photos…"), Location = new Point(12, y), Size = new Size(140, 28) };
            var clear = new Button { Text = T("Wyczyść", "Clear"), Location = new Point(160, y), Size = new Size(90, 28) };
            photoLabel = new Label { Location = new Point(262, y + 6), AutoSize = true };
            choose.Click += (_, _) =>
            {
                using var d = new OpenFileDialog { Multiselect = true, Filter = "Images|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff", Title = T("Wybierz do 12 zdjęć", "Choose up to 12 photos") };
                if (d.ShowDialog(this) == DialogResult.OK) { Settings.ImportPhotos(d.FileNames); UpdatePhotos(); }
            };
            clear.Click += (_, _) => { Settings.ImportPhotos(Array.Empty<string>()); UpdatePhotos(); };
            p.Controls.AddRange(new Control[] { choose, clear, photoLabel });
            UpdatePhotos();
        });
        Tab(T("Info", "About"), (p, y) => {
            var l = new Label
            {
                Location = new Point(14, 14), Size = new Size(460, 200),
                Text = $"Matrix Rain {Version}\n\n" + T("Autor", "By") + $": {Author}\n" + T("Licencja", "License") + $": MIT\n\n" +
                       T("Wygaszacz ekranu w C# + Direct3D 11.\n\nNieoficjalny projekt fanowski, niezwiązany z filmem „Matrix” ani jego właścicielami.",
                         "Screen saver written in C# + Direct3D 11.\n\nUnofficial fan project, not affiliated with the film “The Matrix” or its owners.")
            };
            var link = new LinkLabel { Text = RepoUrl, Location = new Point(14, 220), AutoSize = true };
            link.LinkClicked += (_, _) => System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(RepoUrl) { UseShellExecute = true });
            p.Controls.AddRange(new Control[] { l, link });
        });
        if (tabIdx < tabs.TabCount) tabs.SelectedIndex = tabIdx;

        var ok = new Button { Text = "OK", Location = new Point(430, 426), Size = new Size(80, 30), DialogResult = DialogResult.OK };
        ok.Click += (_, _) => { S.Save(); Close(); };
        var cancel = new Button { Text = T("Anuluj", "Cancel"), Location = new Point(340, 426), Size = new Size(80, 30) };
        cancel.Click += (_, _) => Close();
        Controls.AddRange(new Control[] { ok, cancel });
        AcceptButton = ok;
    }

    void UpdatePhotos()
    {
        int n = Settings.PhotoCount();
        if (photoLabel != null) photoLabel.Text = n == 0 ? T("brak zdjęć", "no photos") : T($"wybrano: {n}", $"selected: {n}");
    }

    void Tab(string title, Action<TabPage, int> build)
    {
        var p = new TabPage(title) { UseVisualStyleBackColor = true, AutoScroll = true };
        tabs.TabPages.Add(p);
        build(p, 14);
    }

    void Slider(TabPage p, ref int y, string label, string key, double min, double max)
    {
        var l = new Label { Text = label, Location = new Point(12, y + 4), Width = 170 };
        var tb = new TrackBar { Minimum = 0, Maximum = 100, TickFrequency = 10, Location = new Point(185, y - 2), Width = 220 };
        var val = new Label { Location = new Point(412, y + 4), Width = 60 };
        tb.Value = (int)Math.Clamp(Math.Round((S[key] - min) / (max - min) * 100), 0, 100);
        void upd() { double v = min + tb.Value / 100.0 * (max - min); S[key] = v; val.Text = v.ToString("0.##"); }
        upd();
        tb.Scroll += (_, _) => upd();
        p.Controls.AddRange(new Control[] { l, tb, val });
        y += 44;
    }

    void Combo(TabPage p, ref int y, string label, string key, string[] items)
    {
        var l = new Label { Text = label, Location = new Point(12, y + 4), Width = 170 };
        var cb = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Location = new Point(185, y), Width = 230 };
        cb.Items.AddRange(items);
        cb.SelectedIndex = Math.Clamp(S.I(key), 0, items.Length - 1);
        cb.SelectedIndexChanged += (_, _) => S[key] = cb.SelectedIndex;
        p.Controls.AddRange(new Control[] { l, cb });
        y += 40;
    }
}
