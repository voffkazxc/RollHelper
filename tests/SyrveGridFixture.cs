// Test-only grid and dummy records. No order/controller/server is instantiated.
using System;
using System.ComponentModel;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Windows.Forms;
using DevExpress.XtraGrid;
using DevExpress.XtraGrid.Columns;
using DevExpress.XtraGrid.Views.Grid;
using Resto.UI.Common.Controls.RestoGrid;

internal sealed class FixtureOrder
{
    public string Number { get; set; }
}

internal static class SyrveGridFixture
{
    private static string office, statePath;
    private static BackgroundForm form;
    private static RestoGrid grid;
    private static GridView view;
    private static int opens, doubleClicks;
    private static string openedNumber = "";

    [STAThread]
    private static void Main(string[] args)
    {
        office = args[0]; statePath = args[1];
        AppDomain.CurrentDomain.AssemblyResolve += delegate(object sender, ResolveEventArgs e)
        {
            string file = Path.Combine(office, new AssemblyName(e.Name).Name + ".dll");
            return File.Exists(file) ? Assembly.LoadFrom(file) : null;
        };
        RunFixture();
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    private static void RunFixture()
    {
        form = new BackgroundForm { ShowInTaskbar = false, ClientSize = new Size(700, 400), WindowState = FormWindowState.Minimized };
        grid = new RestoGrid { Name = "gridDeliveries", Bounds = new Rectangle(0, 0, 700, 400) };
        form.Controls.Add(grid);
        IntPtr handle = grid.Handle;
        grid.ForceInitialize();
        view = (GridView)grid.MainView;
        grid.DataSource = new BindingList<FixtureOrder> {
            new FixtureOrder { Number = "741877" }, new FixtureOrder { Number = "741878" }
        };
        view.PopulateColumns();
        view.Columns["Number"].Caption = "№";
        view.Columns["Number"].Width = 180;
        view.OptionsBehavior.Editable = false;
        view.OptionsView.ShowAutoFilterRow = true;
        view.OptionsView.ShowGroupPanel = false;
        view.Columns["Number"].FilterInfo = new ColumnFilterInfo("[Number] = '741877'");
        view.FocusedRowHandle = GridControl.AutoFilterRowHandle;
        grid.ContextAction += delegate(object sender, ContextMenuActionArgs action)
        {
            if (action.Action == ActionType.EDIT)
            {
                FixtureOrder record = view.GetFocusedRow() as FixtureOrder;
                if (record != null) { opens++; openedNumber = record.Number; }
            }
            WriteState();
        };
        grid.RowDoubleClicked += delegate(object sender, int row) { doubleClicks++; WriteState(); };
        form.Shown += delegate
        {
            using (Bitmap bitmap = new Bitmap(700, 400))
                grid.DrawToBitmap(bitmap, new Rectangle(0, 0, 700, 400));
            WriteState();
        };
        Application.Run(form);
    }

    private static void WriteState()
    {
        File.WriteAllText(statePath, string.Join(",", new object[] {
            form.Handle.ToInt64(), grid.Handle.ToInt64(), view.DataRowCount,
            view.FocusedRowHandle, opens, doubleClicks, openedNumber,
            (int)form.WindowState, grid.ContainsFocus ? 1 : 0
        }));
    }
}
