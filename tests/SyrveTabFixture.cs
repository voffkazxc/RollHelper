// Test-only host for the installed Syrve tab-control component. No Syrve
// application, login, network request or order handler is started here.
using System;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Windows.Forms;
using DevExpress.XtraTab;
using Resto.UI.Common.Controls.TabManager;

internal sealed class BackgroundForm : Form
{
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams p = base.CreateParams;
            p.ExStyle |= 0x08000080; // NOACTIVATE | TOOLWINDOW
            return p;
        }
    }
}

internal static class SyrveTabFixture
{
    private static string office;
    private static string statePath;
    private static BackgroundForm form;
    private static RestoTabControl tabs;
    private static int keyDowns;
    private static int switches;
    private static int lastKeyData;

    [STAThread]
    private static void Main(string[] args)
    {
        office = args[0];
        statePath = args[1];
        AppDomain.CurrentDomain.AssemblyResolve += delegate(object sender, ResolveEventArgs e)
        {
            string path = Path.Combine(office, new AssemblyName(e.Name).Name + ".dll");
            return File.Exists(path) ? Assembly.LoadFrom(path) : null;
        };
        RunFixture();
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    private static void RunFixture()
    {
        form = new BackgroundForm();
        form.ShowInTaskbar = false;
        form.WindowState = FormWindowState.Minimized;
        tabs = new RestoTabControl();
        tabs.Name = "tabControlMain";
        tabs.Dock = DockStyle.Fill;
        foreach (string title in new string[] { "Deliveries", "Other" })
        {
            XtraTabPage page = new XtraTabPage { Text = title, AccessibleName = title };
            UserControl content = new UserControl { Dock = DockStyle.Fill, Name = title, Text = title, AccessibleName = title };
            content.Controls.Add(new TextBox { Text = "Test content", Dock = DockStyle.Top });
            page.Controls.Add(content);
            tabs.TabPages.Add(page);
        }
        tabs.KeyDown += delegate(object sender, KeyEventArgs e)
        {
            keyDowns++;
            lastKeyData = (int)e.KeyData;
            // Match Syrve's observed shortcut predicate; only change test tabs.
            if (e.KeyCode == Keys.Tab && e.Modifiers == Keys.Control)
            {
                tabs.SelectedTabPageIndex = 1 - tabs.SelectedTabPageIndex;
                switches++;
                e.Handled = true;
            }
            WriteState();
        };
        form.Controls.Add(tabs);
        IntPtr tabHandle = tabs.Handle;
        foreach (XtraTabPage page in tabs.TabPages)
        {
            IntPtr pageHandle = page.Handle;
            foreach (Control child in page.Controls)
            {
                IntPtr childHandle = child.Handle;
                foreach (Control nested in child.Controls)
                {
                    IntPtr nestedHandle = nested.Handle;
                }
            }
        }
        form.Shown += delegate { WriteState(); };
        Application.Run(form);
    }

    private static void WriteState()
    {
        File.WriteAllText(statePath, string.Join(",", new object[] {
            form.Handle.ToInt64(), tabs.Handle.ToInt64(),
            tabs.SelectedTabPageIndex, keyDowns, switches,
            (int)form.WindowState, tabs.ContainsFocus ? 1 : 0, lastKeyData
        }));
    }
}
