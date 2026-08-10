using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Automation;
using System.Windows.Forms;
using System.Net;
using System.IO;
using System.Web.Script.Serialization;
using System.Collections.Generic;

namespace RollhouseAddon
{
    class Program
    {
        // ================= GLOBAL HOTKEY HOOK =================
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("user32.dll")]
        private static extern bool SetCursorPos(int X, int Y);

        [DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
        public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);

        private const int MOUSEEVENTF_LEFTDOWN = 0x02;
        private const int MOUSEEVENTF_LEFTUP = 0x04;

        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN = 0x0100;
        private static LowLevelKeyboardProc _proc = HookCallback;
        private static IntPtr _hookID = IntPtr.Zero;

        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

        static void Main(string[] args)
        {
            Console.WriteLine("Rollhouse Addon запущен!");
            Console.WriteLine("Нажми F9 в iiko для автоматической пробивки.");
            Console.WriteLine("Нажми Ctrl+C в этом окне для закрытия программы.");

            _hookID = SetHook(_proc);
            Application.Run();
            UnhookWindowsHookEx(_hookID);
        }

        private static IntPtr SetHook(LowLevelKeyboardProc proc)
        {
            using (Process curProcess = Process.GetCurrentProcess())
            using (ProcessModule curModule = curProcess.MainModule)
            {
                return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
            }
        }

        private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN)
            {
                int vkCode = Marshal.ReadInt32(lParam);
                if ((Keys)vkCode == Keys.F9)
                {
                    // Запуск макроса в отдельном потоке, чтобы не блокировать хук
                    Thread t = new Thread(ProcessOrder);
                    t.SetApartmentState(ApartmentState.STA); // Нужно для UIAutomation
                    t.Start();
                }
            }
            return CallNextHookEx(_hookID, nCode, wParam, lParam);
        }

        // ================= MACRO LOGIC =================

        private static void ProcessOrder()
        {
            try
            {
                Console.WriteLine("\n[F9] Запуск обработки заказа...");
                
                // 1. Поиск окна iiko (Поиск по подстроке)
                AutomationElement iikoWindow = null;
                AutomationElementCollection desktopWindows = AutomationElement.RootElement.FindAll(TreeScope.Children, Condition.TrueCondition);
                foreach (AutomationElement window in desktopWindows)
                {
                    try
                    {
                        string name = window.Current.Name.ToLower();
                        if (name.Contains("iiko") || name.Contains("syrve") || name.Contains("доставка"))
                        {
                            iikoWindow = window;
                            break;
                        }
                    }
                    catch { } // Игнорируем закрытые окна
                }

                if (iikoWindow == null)
                {
                    Console.WriteLine("ОШИБКА: Окно iiko не найдено.");
                    return;
                }
                
                Console.WriteLine("Окно iiko найдено.");

                // 2. Читаем сырой комментарий
                AutomationElement commentField = FindElementById(iikoWindow, "memoEditDeliveryComment");
                if (commentField == null)
                {
                    Console.WriteLine("ОШИБКА: Поле Комментарий к заказу не найдено.");
                    return;
                }

                string rawText = GetText(commentField);
                if (string.IsNullOrWhiteSpace(rawText))
                {
                    Console.WriteLine("Комментарий пуст. Парсить нечего.");
                    return;
                }

                Console.WriteLine("Сырой текст: " + rawText);

                // 3. Парсинг
                var parsed = ParseComment(rawText);
                
                // 4. Запрос подарка
                string giftPlu = GetGiftFromServer();
                if (!string.IsNullOrEmpty(giftPlu))
                {
                    Console.WriteLine("Получен подарок: " + giftPlu);
                }

                // 5. Вставляем текст в поля (Нативно)
                SetText(commentField, parsed["kitchen_note"]);

                AutomationElement addressField = FindElementById(iikoWindow, "memoEditDeliveryAddressComment");
                if (addressField != null && !string.IsNullOrEmpty(parsed["address_note"]))
                {
                    SetText(addressField, parsed["address_note"]);
                }

                if (!string.IsNullOrEmpty(parsed["time"]))
                {
                    AutomationElement timeField = FindElementById(iikoWindow, "timeEditDeliveryTime");
                    if (timeField != null)
                    {
                        timeField.SetFocus();
                        Thread.Sleep(50);
                        SendKeys.SendWait("^a{DELETE}" + parsed["time"].Replace(":", ""));
                    }
                }

                // 6. Фокус таблицы и пробивка блюд
                AutomationElement gridControl = FindElementById(iikoWindow, "treeListItems");
                if (gridControl != null)
                {
                    Console.WriteLine("Таблица найдена, фокусируем кликом...");
                    try
                    {
                        System.Windows.Rect rect = gridControl.Current.BoundingRectangle;
                        int cx = (int)(rect.Left + rect.Width / 2);
                        int cy = (int)(rect.Top + 40); // Чуть ниже заголовка таблицы
                        
                        SetCursorPos(cx, cy);
                        Thread.Sleep(50);
                        mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
                        Thread.Sleep(150);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("Не удалось кликнуть по таблице: " + ex.Message);
                        gridControl.SetFocus();
                        Thread.Sleep(200);
                    }

                    PunchItem("00133", int.Parse(parsed["sticks_norm"]));
                    PunchItem("02562", int.Parse(parsed["sticks_edu"]));
                    PunchItem("00135", int.Parse(parsed["siv_soy"]));
                    PunchItem("00136", int.Parse(parsed["siv_imb"]));
                    PunchItem("00137", int.Parse(parsed["siv_vas"]));
                    
                    if (!string.IsNullOrEmpty(giftPlu))
                    {
                        PunchItem(giftPlu, 1);
                    }
                    
                    Console.WriteLine("УСПЕХ! Сценарий выполнен.");
                }
                else
                {
                    Console.WriteLine("ОШИБКА: Таблица treeListItems не найдена!");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("КРИТИЧЕСКАЯ ОШИБКА: " + ex.ToString());
            }
        }

        private static void PunchItem(string plu, int qty)
        {
            if (qty <= 0) return;
            SendKeys.SendWait("{PGDN}{ENTER}");
            Thread.Sleep(100);
            SendKeys.SendWait(plu + "{DOWN}");
            Thread.Sleep(50);
            if (qty > 1)
            {
                SendKeys.SendWait("{TAB}");
                Thread.Sleep(50);
                SendKeys.SendWait("^a{DELETE}" + qty + "{ENTER}");
            }
            else
            {
                SendKeys.SendWait("{ENTER}");
            }
            Thread.Sleep(50);
        }

        private static Dictionary<string, string> ParseComment(string text)
        {
            var res = new Dictionary<string, string>
            {
                { "sticks_norm", "0" }, { "sticks_edu", "0" },
                { "siv_soy", "0" }, { "siv_imb", "0" }, { "siv_vas", "0" },
                { "kitchen_note", "" }, { "address_note", text }, { "time", "" }
            };

            var mTime = Regex.Match(res["address_note"], @"(?i)Время:\s*\d{4}-\d{2}-\d{2}\s*(\d{2}:\d{2})");
            if (mTime.Success) res["time"] = mTime.Groups[1].Value;

            res["sticks_norm"] = ExtractNumberAndRemove(ref res, @"(?i)(обычные|звичайні)[\s:-]*(\d+)");
            res["sticks_edu"] = ExtractNumberAndRemove(ref res, @"(?i)(учебные|учеб|навчальні)[\s:-]*(\d+)");
            res["siv_soy"] = ExtractNumberAndRemove(ref res, @"(?i)(соевый|соєвий)[\s:-]*(\d+)");
            res["siv_imb"] = ExtractNumberAndRemove(ref res, @"(?i)(имбирь|імбир)[\s:-]*(\d+)");
            res["siv_vas"] = ExtractNumberAndRemove(ref res, @"(?i)(васаб[иі])[\s:-]*(\d+)");

            var mKitchen = Regex.Match(res["address_note"], @"(?i)(без\s+[а-яА-ЯёЁіІїЇєЄ]+|соус окремо|алерг[а-я]+|не\s+класти[а-я\s]+)");
            if (mKitchen.Success)
            {
                res["kitchen_note"] = mKitchen.Value.Trim();
                res["address_note"] = res["address_note"].Replace(mKitchen.Value, "");
            }

            res["address_note"] = Regex.Replace(res["address_note"], @"(?i)(Android v[\d\.]+|iOS v[\d\.]+)[,\s;]*", "");
            res["address_note"] = Regex.Replace(res["address_note"], @"(?i)Время:\s*\d{4}-\d{2}-\d{2}\s*\d{2}:\d{2}\s*(?:\([^)]+\))?[,\s]*", "");
            res["address_note"] = Regex.Replace(res["address_note"], @"(?i)(Адрес|Адреса):\s*.*?(?=(Оплата|Коментар|$))", "");
            res["address_note"] = Regex.Replace(res["address_note"], @"(?i)Оплата:\s*([а-яА-ЯёЁіІїЇєЄa-zA-Z]+)[,\s]*", "");

            res["address_note"] = Regex.Replace(res["address_note"], @"\s+", " ").Trim();
            res["address_note"] = Regex.Replace(res["address_note"], @"^[,.\s]+|[,.\s]+$", "");

            return res;
        }

        private static string ExtractNumberAndRemove(ref Dictionary<string, string> res, string pattern)
        {
            var match = Regex.Match(res["address_note"], pattern);
            if (match.Success)
            {
                res["address_note"] = res["address_note"].Replace(match.Value, "");
                return match.Groups[2].Value;
            }
            return "0";
        }

        private static string GetGiftFromServer()
        {
            try
            {
                HttpWebRequest req = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:5000/api/iiko/gift");
                req.Timeout = 2000;
                using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
                using (StreamReader sr = new StreamReader(resp.GetResponseStream()))
                {
                    string json = sr.ReadToEnd();
                    var jss = new JavaScriptSerializer();
                    var dict = jss.Deserialize<Dictionary<string, object>>(json);
                    if (dict != null && dict.ContainsKey("gift_plu") && dict["gift_plu"] != null)
                    {
                        return dict["gift_plu"].ToString();
                    }
                }
            }
            catch { }
            return null;
        }

        private static AutomationElement FindElementById(AutomationElement root, string autoId)
        {
            Condition cond = new PropertyCondition(AutomationElement.AutomationIdProperty, autoId);
            return root.FindFirst(TreeScope.Descendants, cond);
        }

        private static string GetText(AutomationElement el)
        {
            object patternObj;
            if (el.TryGetCurrentPattern(ValuePattern.Pattern, out patternObj))
            {
                return ((ValuePattern)patternObj).Current.Value;
            }
            return "";
        }

        private static void SetText(AutomationElement el, string text)
        {
            if (string.IsNullOrEmpty(text)) text = "";
            object patternObj;
            if (el.TryGetCurrentPattern(ValuePattern.Pattern, out patternObj))
            {
                ((ValuePattern)patternObj).SetValue(text);
            }
        }
    }
}
