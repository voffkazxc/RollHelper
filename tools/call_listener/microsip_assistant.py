import os
import sys
sys.stderr = open('stderr.log', 'w')
print('Started!', file=sys.stderr)
import time
import socket
import threading
import queue
import re
import json
import numpy as np
import pyaudiowpatch as pyaudio
import win32com.client
import win32api
import win32con
import tkinter as tk
from tkinter import ttk, messagebox
import sounddevice as sd
import soundfile as sf
import torch
from faster_whisper import WhisperModel
import keyboard
import csv
from datetime import datetime
import os
import traceback
import math
# Adjust path to import classify
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
try:
    from tools.call_listener.call_listen import classify
except ImportError:
    def classify(text: str):
        return "empty", "no_keywords"

# --- Constants & Config ---
CONFIG_FILE = os.path.join(os.path.dirname(__file__), "assistant_config.json")
GREETING_WAV = os.path.join(os.path.dirname(__file__), "..", "..", "data", "call_listener", "greeting.wav")
UDP_PORT = 5055
MICROSIP_EXE = r"C:\Users\voffk\AppData\Local\MicroSIP\microsip.exe"
WHISPER_MODEL = "small"
AUDIO_CHUNK = 512
VAD_THRESHOLD = 0.05
VAD_SILENCE_MS = 500
FIRST_SPEECH_TIMEOUT_MS = 15000

class AppState:
    IDLE = "IDLE"
    DIALING = "DIALING"
    CONNECTED = "CONNECTED"
    GREETING = "GREETING"
    WAITING_FOR_FIRST_SPEECH = "WAITING_FOR_FIRST_SPEECH"
    IN_SPEECH = "IN_SPEECH"
    ENDPOINTING = "ENDPOINTING"
    ASR_DECISION = "ASR_DECISION"
    RESULT = "RESULT"

class MicroSIPAssistantApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("MICRO-SIP CALL ASSISTANT")
        self.geometry("700x850")
        self.configure(bg="#1e1e2e")
        self.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        self.state = AppState.IDLE
        self.phone_queue = []
        self.seen_phones = set()
        self.queue_index = 0
        
        self.review_queue = []
        self.partial_asr_queue = queue.Queue()
        self.dial_start_time = 0.0
        self.dial_timer_id = None
        
        self.audio_thread_active = True
        self.audio_queue = queue.Queue()
        self.is_recording = False
        self.audio_level = 0.0
        self._desired_device_idx = -1  # written from main thread, read from audio thread
        self.pyaudio_instance = pyaudio.PyAudio()
        
        # Load Config
        self.config = {"client_device": "", "greeting_device": ""}
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    self.config = json.load(f)
            except: pass
            
        # Status indicators
        self.status_flags = {
            "MICROSIP": "READY",
            "CONNECTED EVENTS": "READY",
            "AUDIO": "READY",
            "ASR": "READY",
            "VAD": "READY",
            "EXCEL": "READY",
            "GREETING": "READY"
        }
        
        self.setup_ui()
        self.check_initial_status()
        self.refresh_devices()
        
        # Threads
        self.udp_thread = threading.Thread(target=self.udp_server_loop, daemon=True)
        self.udp_thread.start()
        
        threading.Thread(target=self.load_models, daemon=True).start()
        
        self.audio_thread = threading.Thread(target=self.audio_capture_loop, daemon=True)
        self.audio_thread.start()
        
        threading.Thread(target=self.partial_asr_worker, daemon=True).start()
        
        keyboard.on_release_key('x', self.on_global_x_pressed)
        
        self.update_level_ui()
        self.update_review_ui()

    def check_initial_status(self):
        if not os.path.exists(MICROSIP_EXE):
            self.status_flags["MICROSIP"] = "ERROR (not found)"
            
        ini_path = r'C:\Users\voffk\AppData\Roaming\MicroSIP\microsip.ini'
        if os.path.exists(ini_path):
            content = ""
            for enc in ['utf-8-sig', 'utf-16', 'utf-8', 'cp1251']:
                try:
                    with open(ini_path, 'r', encoding=enc) as f:
                        content = f.read()
                    break
                except UnicodeDecodeError:
                    pass
            if "CALL_START" not in content or "CALL_END" not in content:
                self.status_flags["CONNECTED EVENTS"] = "ERROR (not configured)"
        else:
            self.status_flags["CONNECTED EVENTS"] = "ERROR (ini missing)"
            
        if not os.path.exists(GREETING_WAV):
            # Create a dummy greeting if none exists
            try:
                sd.default.samplerate = 16000
                sd.default.channels = 1
                t = np.linspace(0, 1, 16000, False)
                tone = np.sin(440 * t * 2 * np.pi).astype(np.float32) * 0.1
                sf.write(GREETING_WAV, tone, 16000)
            except:
                self.status_flags["GREETING"] = "ERROR (wav missing)"
        
        self.update_status_ui()
        
    def load_models(self):
        try:
            self.vad_model, utils = torch.hub.load(
                repo_or_dir='snakers4/silero-vad', model='silero_vad',
                force_reload=False, onnx=False
            )
            self.status_flags["VAD"] = "READY"
        except Exception as e:
            self.status_flags["VAD"] = f"ERROR ({e})"
            
        try:
            self.whisper_model = WhisperModel(
                WHISPER_MODEL, 
                device="cpu", 
                compute_type="int8"
            )
            self.status_flags["ASR"] = "SMALL / CPU / READY"
        except Exception as e:
            self.status_flags["ASR"] = f"ERROR ({e})"
            
        self.update_status_ui()

    def setup_ui(self):
        style = ttk.Style(self)
        style.theme_use('clam')
        style.configure('TLabel', background="#1e1e2e", foreground="#cdd6f4")
        
        # Status Bar
        self.frame_status = tk.Frame(self, bg="#11111b", bd=1, relief=tk.SUNKEN)
        self.frame_status.pack(fill=tk.X, padx=10, pady=5)
        self.lbl_status = ttk.Label(self.frame_status, text="Checking status...", font=('Consolas', 9))
        self.lbl_status.pack(side=tk.LEFT, padx=5, pady=2)
        
        # Audio Settings
        frame_audio = tk.LabelFrame(self, text="Настройки звука", bg="#1e1e2e", fg="#bac2de", font=('Segoe UI', 10, 'bold'))
        frame_audio.pack(fill=tk.X, padx=10, pady=5)
        
        ttk.Label(frame_audio, text="Источник клиента (WASAPI Loopback):").grid(row=0, column=0, padx=5, pady=2, sticky="w")
        self.cb_client_dev = ttk.Combobox(frame_audio, width=45, state="readonly")
        self.cb_client_dev.grid(row=0, column=1, padx=5, pady=2)
        self.cb_client_dev.bind("<<ComboboxSelected>>", self._on_client_device_changed)
        
        ttk.Label(frame_audio, text="Микрофон MicroSIP (Для приветствия):").grid(row=1, column=0, padx=5, pady=2, sticky="w")
        self.cb_greet_dev = ttk.Combobox(frame_audio, width=45, state="readonly")
        self.cb_greet_dev.grid(row=1, column=1, padx=5, pady=2)
        self.cb_greet_dev.bind("<<ComboboxSelected>>", self.save_config)
        
        btn_test = tk.Button(frame_audio, text="Тест звука", command=self.test_audio, bg="#313244", fg="#cdd6f4")
        btn_test.grid(row=0, column=2, padx=5, pady=2)
        btn_refresh = tk.Button(frame_audio, text="Обновить", command=self.refresh_devices, bg="#313244", fg="#cdd6f4")
        btn_refresh.grid(row=1, column=2, padx=5, pady=2)
        
        # Audio Info Frame
        self.frame_audio_info = tk.Frame(frame_audio, bg="#1e1e2e")
        self.frame_audio_info.grid(row=2, column=0, columnspan=3, pady=5)
        
        self.lbl_rate = ttk.Label(self.frame_audio_info, text="Rate: --- Hz", font=('Consolas', 10), width=16, anchor="w")
        self.lbl_rate.pack(side=tk.LEFT, padx=5)
        
        self.canvas_eq = tk.Canvas(self.frame_audio_info, width=200, height=20, bg="#11111b", bd=0, highlightthickness=0)
        self.canvas_eq.pack(side=tk.LEFT, padx=10)
        
        self.lbl_db = ttk.Label(self.frame_audio_info, text=" -80.0 dB", font=('Consolas', 10), width=10, anchor="e")
        self.lbl_db.pack(side=tk.LEFT, padx=5)
        
        # Live Display
        self.frame_live = tk.LabelFrame(self, text="ТЕКУЩИЙ ЗВОНОК", bg="#1e1e2e", fg="#89b4fa", font=('Segoe UI', 12, 'bold'))
        self.frame_live.pack(fill=tk.X, padx=10, pady=5)
        
        self.lbl_phone = ttk.Label(self.frame_live, text="Номер: ---", font=('Segoe UI', 16, 'bold'), foreground="#89b4fa")
        self.lbl_phone.pack(pady=(10, 2))
        
        self.lbl_queue = ttk.Label(self.frame_live, text="Очередь: 0 / 0", foreground="#a6adc8")
        self.lbl_queue.pack(pady=2)
        
        self.lbl_state = ttk.Label(self.frame_live, text=f"СОСТОЯНИЕ: ● {self.state}", font=('Segoe UI', 18, 'bold'), foreground="#f38ba8")
        self.lbl_state.pack(pady=10)
        
        ttk.Label(self.frame_live, text="Живой текст клиента:").pack(pady=(5, 2))
        self.txt_client = tk.Text(self.frame_live, height=3, width=60, font=('Segoe UI', 13), bg="#313244", fg="#cdd6f4", wrap=tk.WORD)
        self.txt_client.pack(pady=5)
        
        self.lbl_decision = ttk.Label(self.frame_live, text="---", font=('Segoe UI', 16, 'bold'), foreground="#a6e3a1")
        self.lbl_decision.pack(pady=10)
        
        # Review Display
        self.frame_review = tk.LabelFrame(self, text="ОЦЕНКА ЗВОНКОВ (Очередь: 0)", bg="#1e1e2e", fg="#f9e2af", font=('Segoe UI', 12, 'bold'))
        self.frame_review.pack(fill=tk.X, padx=10, pady=5)
        
        self.lbl_rev_phone = ttk.Label(self.frame_review, text="Номер: ---", font=('Segoe UI', 14, 'bold'), foreground="#cdd6f4")
        self.lbl_rev_phone.pack(pady=5)
        
        self.txt_rev_client = tk.Text(self.frame_review, height=3, width=60, font=('Segoe UI', 11), bg="#313244", fg="#cdd6f4", wrap=tk.WORD)
        self.txt_rev_client.pack(pady=5)
        
        self.lbl_rev_decision = ttk.Label(self.frame_review, text="---", font=('Segoe UI', 16, 'bold'), foreground="#a6e3a1")
        self.lbl_rev_decision.pack(pady=5)
        
        frame_rating = tk.Frame(self.frame_review, bg="#1e1e2e")
        frame_rating.pack(pady=5)
        for i in range(1, 6):
            btn = tk.Button(frame_rating, text=str(i), font=('Segoe UI', 12, 'bold'), width=4, 
                            bg="#45475a", fg="#cdd6f4", command=lambda x=i: self.save_result(x))
            btn.pack(side=tk.LEFT, padx=5)
            
        frame_corr = tk.Frame(self.frame_review, bg="#1e1e2e")
        frame_corr.pack(pady=5)
        tk.Button(frame_corr, text="Positive", bg="#a6e3a1", fg="#11111b", command=lambda: self.save_result(manual_decision="POSITIVE")).pack(side=tk.LEFT, padx=5)
        tk.Button(frame_corr, text="Negative", bg="#f38ba8", fg="#11111b", command=lambda: self.save_result(manual_decision="NEGATIVE")).pack(side=tk.LEFT, padx=5)
        tk.Button(frame_corr, text="Manual", bg="#f9e2af", fg="#11111b", command=lambda: self.save_result(manual_decision="MANUAL")).pack(side=tk.LEFT, padx=5)
            
        # Controls
        frame_controls = tk.Frame(self, bg="#1e1e2e")
        frame_controls.pack(pady=10)
        tk.Button(frame_controls, text="Позвонить", font=('Segoe UI', 11, 'bold'), bg="#89b4fa", fg="#11111b", width=12, command=self.btn_call_clicked).grid(row=0, column=0, padx=10)
        tk.Button(frame_controls, text="Сбросить", font=('Segoe UI', 11, 'bold'), bg="#f38ba8", fg="#11111b", width=12, command=self.btn_hangup_clicked).grid(row=0, column=1, padx=10)
        tk.Button(frame_controls, text="Следующий", font=('Segoe UI', 11, 'bold'), bg="#cba6f7", fg="#11111b", width=12, command=self.btn_next_clicked).grid(row=0, column=2, padx=10)
        tk.Button(frame_controls, text="Загрузить Excel", font=('Segoe UI', 10), bg="#45475a", fg="#cdd6f4", command=self.load_from_excel).grid(row=1, column=0, columnspan=3, pady=10)

    def update_status_ui(self):
        text = " | ".join([f"{k}: {v}" for k, v in self.status_flags.items()])
        self.after(0, lambda: self.lbl_status.config(text=text))

    def refresh_devices(self):
        self.pyaudio_instance = pyaudio.PyAudio() # refresh
        client_opts = []
        greet_opts = []
        
        wasapi_info = self.pyaudio_instance.get_host_api_info_by_type(pyaudio.paWASAPI)
        for i in range(self.pyaudio_instance.get_device_count()):
            dev = self.pyaudio_instance.get_device_info_by_index(i)
            name = f"[{i}] {dev['name']}"
            if dev["hostApi"] == wasapi_info["index"]:
                if dev["isLoopbackDevice"]:
                    client_opts.append(name)
                elif dev["maxOutputChannels"] > 0:
                    greet_opts.append(name)
                    
        self.cb_client_dev['values'] = client_opts
        self.cb_greet_dev['values'] = greet_opts
        
        # Restore saved
        for opt in client_opts:
            if opt == self.config.get("client_device", ""):
                self.cb_client_dev.set(opt)
        for opt in greet_opts:
            if opt == self.config.get("greeting_device", ""):
                self.cb_greet_dev.set(opt)
                
        if not self.cb_client_dev.get() and client_opts:
            self.cb_client_dev.set(client_opts[0])
        if not self.cb_greet_dev.get() and greet_opts:
            self.cb_greet_dev.set(greet_opts[0])
            
        self.save_config()

    def _on_client_device_changed(self, event=None):
        """Called on main thread when user picks a new loopback device."""
        dev_str = self.cb_client_dev.get()
        idx = int(dev_str.split("]")[0][1:]) if dev_str else -1
        self._desired_device_idx = idx  # audio thread reads this
        self.save_config()

    def _set_audio_status(self, msg):
        """Thread-safe status update via after()."""
        self.status_flags["AUDIO"] = msg
        self.update_status_ui()

    def save_config(self, event=None):
        self.config["client_device"] = self.cb_client_dev.get()
        self.config["greeting_device"] = self.cb_greet_dev.get()
        # Sync desired device idx
        dev_str = self.cb_client_dev.get()
        self._desired_device_idx = int(dev_str.split("]")[0][1:]) if dev_str else -1
        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(self.config, f)
            self.status_flags["AUDIO"] = "READY"
        except Exception as e:
            self.status_flags["AUDIO"] = f"ERROR ({e})"
        self.update_status_ui()
        
    def test_audio(self):
        """Toggle monitoring indicator for client loopback source."""
        # This button just toggles a visual flag; monitoring runs continuously
        dev_str = self.cb_client_dev.get()
        if not dev_str:
            messagebox.showwarning("Мониторинг", "Сначала выберите устройство 'Источник клиента'")
            return
        messagebox.showinfo(
            "Мониторинг",
            f"Мониторинг работает непрерывно.\n"
            f"Устройство: {dev_str}\n"
            f"Включите YouTube — индикатор должен двигаться."
        )
        
    def update_level_ui(self):
        if not hasattr(self, 'eq_history'):
            self.eq_history = [0.0] * 25
            self.last_amp = 0.0
            
        rms = self.audio_level / 10.0
        if rms > 1e-4:
            db = 20 * math.log10(rms)
        else:
            db = -80.0
            
        db_str = f"{db:>6.1f} dB"
        
        # Scale dB to [0.0, 1.0] range where -60dB is 0 and -10dB is 1
        if db > -60.0:
            amp = (db + 60.0) / 50.0
            amp = min(1.0, max(0.0, amp))
        else:
            amp = 0.0
            
        # Add new value to history
        self.eq_history.pop(0)
        
        # Apply smoothing (attack/release) to the raw amplitude
        if amp > self.last_amp:
            # Fast attack
            self.last_amp = amp
        else:
            # Smooth release
            self.last_amp = max(0.0, self.last_amp - 0.05)
            
        self.eq_history.append(self.last_amp)
        
        # Draw canvas
        self.canvas_eq.delete("all")
        w = 200
        h = 20
        bar_w = w / 25
        gap = 2
        
        for i, val in enumerate(self.eq_history):
            if val > 0.02:
                bar_h = val * h
                x0 = i * bar_w + gap/2
                x1 = x0 + bar_w - gap
                y0 = h - bar_h
                y1 = h
                # Color gradient based on height
                if val > 0.8: color = "#f38ba8" # red
                elif val > 0.5: color = "#f9e2af" # yellow
                else: color = "#a6e3a1" # green
                self.canvas_eq.create_rectangle(x0, y0, x1, y1, fill=color, outline="")
            
        dev_str = self.cb_client_dev.get()
        idx_dev = int(dev_str.split("]")[0][1:]) if dev_str else -1
        rate = 16000
        if idx_dev >= 0:
            try:
                rate = int(self.pyaudio_instance.get_device_info_by_index(idx_dev)["defaultSampleRate"])
            except: pass
            
        self.lbl_rate.config(text=f"Rate: {rate} Hz")
        self.lbl_db.config(text=db_str)
        self.after(50, self.update_level_ui)

    def trigger_from_excel(self):
        self.after(0, self.lift)
        self.after(0, self.focus_force)
        self.after(0, self.load_from_excel)

    def load_from_excel(self):
        try:
            xl = win32com.client.GetActiveObject("Excel.Application")
            sheet = xl.ActiveSheet
            last_row = sheet.Cells(sheet.Rows.Count, 11).End(-4162).Row
            
            queue_list = []
            seen = set()
            
            for i in range(1, last_row + 1):
                val = sheet.Cells(i, 11).Value
                if not val or val == 0: continue
                val_str = str(val)
                clean_num = re.sub(r'[^\d+]', '', val_str)
                digits = re.sub(r'\D', '', clean_num)
                dedup_key = digits
                if len(digits) >= 12 and digits.startswith("380"): dedup_key = digits[3:]
                elif len(digits) == 10 and digits.startswith("0"): dedup_key = digits[1:]
                elif len(digits) >= 9: dedup_key = digits[-9:]
                
                if len(clean_num) >= 7 and dedup_key:
                    if dedup_key in seen: continue
                    seen.add(dedup_key)
                    queue_list.append(clean_num)
                    
            self.phone_queue = queue_list
            self.seen_phones = seen
            self.queue_index = 0
            self.update_queue_ui()
            self.status_flags["EXCEL"] = "READY"
            messagebox.showinfo("Загружено", f"Загружено {len(queue_list)} уникальных номеров из Excel.")
        except Exception as e:
            self.status_flags["EXCEL"] = f"ERROR ({e})"
            messagebox.showerror("Ошибка", f"Не удалось прочитать Excel (убедитесь, что файл открыт):\n{str(e)}")
        self.update_status_ui()

    def update_queue_ui(self):
        self.lbl_queue.config(text=f"Очередь: {self.queue_index + 1} / {len(self.phone_queue)}")
        if 0 <= self.queue_index < len(self.phone_queue):
            self.current_phone = self.phone_queue[self.queue_index]
            self.lbl_phone.config(text=f"Номер: {self.current_phone}")
        else:
            self.current_phone = ""
            self.lbl_phone.config(text="Номер: ---")

    def set_state(self, new_state):
        self.state = new_state
        color = "#f38ba8"
        if new_state in (AppState.CONNECTED, AppState.IN_SPEECH): color = "#a6e3a1"
        elif new_state == AppState.WAITING_FOR_FIRST_SPEECH: color = "#f9e2af"
        self.after(0, lambda: self.lbl_state.config(text=f"СОСТОЯНИЕ: ● {new_state}", foreground=color))

    def auto_next_call(self):
        if not self.auto_calling: return
        if self.queue_index < len(self.phone_queue):
            self.action_call()
        else:
            self.auto_calling = False
            self.after(0, lambda: messagebox.showinfo("Обзвон завершен", "Очередь закончилась!"))

    def btn_call_clicked(self):
        self.auto_calling = True
        self.action_call()
        
    def btn_hangup_clicked(self):
        self.auto_calling = False
        self.action_hangup()
        
    def btn_next_clicked(self):
        self.auto_calling = False
        self.action_next()

    def check_dial_timeout(self):
        if self.state == AppState.DIALING:
            if time.time() - self.dial_start_time >= 25.0:
                self.after(0, lambda: self.txt_client.insert(tk.END, "\n[NO ANSWER - 25s TIMEOUT]"))
                self.action_hangup()
                self.action_next()
                self.after(1500, self.auto_next_call)
            else:
                self.dial_timer_id = self.after(1000, self.check_dial_timeout)

    def action_next(self):
        if self.queue_index < len(self.phone_queue):
            self.queue_index += 1
            self.update_queue_ui()
        self.set_state(AppState.IDLE)
        self.txt_client.delete(1.0, tk.END)
        self.lbl_decision.config(text="---", foreground="#a6e3a1")
        self.is_recording = False
        if self.dial_timer_id:
            self.after_cancel(self.dial_timer_id)
            self.dial_timer_id = None
        
    def action_call(self):
        if not self.current_phone: return
        if self.state != AppState.IDLE: return
        self.txt_client.delete(1.0, tk.END)
        self.lbl_decision.config(text="---", foreground="#a6e3a1")
        self.set_state(AppState.DIALING)
        self.dial_start_time = time.time()
        self.check_dial_timeout()
        os.system(f'start "" "{MICROSIP_EXE}" {self.current_phone}')

    def action_hangup(self):
        if self.state == AppState.IDLE: return
        self.set_state(AppState.IDLE)
        self.is_recording = False
        if getattr(self, 'dial_timer_id', None):
            self.after_cancel(self.dial_timer_id)
            self.dial_timer_id = None
        if getattr(self, 'delayed_hangup_timer', None):
            self.after_cancel(self.delayed_hangup_timer)
            self.delayed_hangup_timer = None
        os.system(f'start "" "{MICROSIP_EXE}" /hangupall')
        
    def udp_server_loop(self):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(("127.0.0.1", UDP_PORT))
        while True:
            data, addr = sock.recvfrom(1024)
            msg = data.decode('utf-8').strip()
            
            def log_msg(m):
                ts = time.strftime('%H:%M:%S')
                self.txt_client.insert(tk.END, f"[{ts}] {m} RECEIVED\n")
                self.txt_client.see(tk.END)
                
            if msg == "CALL_START":
                self.after(0, log_msg, "CALL_START")
                
                timestamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
                os.makedirs("logs", exist_ok=True)
                self.current_call_log_path = f"logs/debug_call_{timestamp}.log"
                self.log_diagnostic("CALL_START")
                
                if self.state == AppState.DIALING:
                    if getattr(self, 'dial_timer_id', None):
                        self.after_cancel(self.dial_timer_id)
                        self.dial_timer_id = None
                    self.set_state(AppState.CONNECTED)
                    self.after(0, self.start_greeting)
            elif msg == "CALL_END":
                self.after(0, log_msg, "CALL_END")
                
                # If the call was active when CALL_END arrived, we must process the end of the call
                was_active = (self.state != AppState.IDLE)
                
                self.after(0, self.action_hangup)
                
                if was_active:
                    self.after(0, self.action_next)
                    if getattr(self, 'auto_calling', False):
                        self.after(1500, self.auto_next_call)
            elif msg == "EXCEL_LOAD":
                self.trigger_from_excel()
                
    def log_diagnostic(self, msg):
        path = getattr(self, 'current_call_log_path', None)
        if path:
            try:
                with open(path, "a", encoding="utf-8") as f:
                    f.write(f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] {msg}\n")
            except: pass

    def save_debug_wav(self):
        if not hasattr(self, 'current_debug_wav_frames') or not self.current_debug_wav_frames:
            return
        audio_data = np.concatenate(self.current_debug_wav_frames)
        path = getattr(self, 'current_call_log_path', 'logs/debug_unknown.log').replace('.log', '.wav')
        try:
            sf.write(path, audio_data, 16000, subtype='PCM_16')
            self.log_diagnostic(f"Saved diagnostic WAV: {path}")
        except Exception as e:
            self.log_diagnostic(f"Failed to save WAV: {e}")
                
    def start_greeting(self):
        self.log_diagnostic("GREETING_SKIPPED")
        self.after(0, self.start_listening)

    def start_listening(self):
        self.log_diagnostic("GREETING_END")
        self.log_diagnostic("WAITING_FOR_FIRST_SPEECH")
        self.set_state(AppState.WAITING_FOR_FIRST_SPEECH)
        self.call_stats = {"max_vad_prob": 0, "max_raw_db": -100, "max_resampled_db": -100}
        self.current_debug_wav_frames = []
        self.is_recording = True
        self.txt_client.delete(1.0, tk.END)
        self.lbl_decision.config(text="---", foreground="#a6e3a1")
        
    def audio_capture_loop(self):
        # Initialize pythoncom for this background thread to avoid WASAPI COM errors
        import pythoncom
        pythoncom.CoInitialize()
        
        # Must instantiate PyAudio in the background thread for WASAPI
        p = pyaudio.PyAudio()
        buffer = []
        speech_started = False
        silence_frames = 0
        wait_frames = 0

        current_idx = -2  # -2 means "not yet initialized"
        current_channels = 1
        stream = None
        rate = 16000
        CHUNKS_PER_SEC = 16000 / 512
        last_open_attempt = 0.0

        while self.audio_thread_active:
            # Read desired device index (set from main thread, GIL-safe)
            wanted_idx = self._desired_device_idx

            if wanted_idx != current_idx:
                # Close existing stream
                if stream is not None:
                    try:
                        stream.stop_stream()
                        stream.close()
                    except Exception:
                        pass
                    stream = None
                    self.audio_level = 0.0

                current_idx = wanted_idx

                if wanted_idx >= 0 and time.time() - last_open_attempt > 1.0:
                    last_open_attempt = time.time()
                    try:
                        dev_info = p.get_device_info_by_index(wanted_idx)
                        rate = int(dev_info["defaultSampleRate"])
                        current_channels = max(1, int(dev_info["maxInputChannels"]))
                        CHUNKS_PER_SEC = 16000 / 512
                        
                        fmt = pyaudio.paFloat32
                        for test_fmt in [pyaudio.paFloat32, pyaudio.paInt16, pyaudio.paInt32]:
                            try:
                                if p.is_format_supported(rate, input_device=wanted_idx, input_channels=current_channels, input_format=test_fmt):
                                    fmt = test_fmt
                                    break
                            except Exception:
                                pass

                        _ch = current_channels  # capture for closure
                        _rate = rate
                        _fmt = fmt

                        def cb(in_data, frame_count, time_info, status,
                               _ch=_ch, _fmt=_fmt):
                            if len(in_data) > 0:
                                if _fmt == pyaudio.paFloat32:
                                    audio = np.frombuffer(in_data, dtype=np.float32)
                                elif _fmt == pyaudio.paInt16:
                                    audio = np.frombuffer(in_data, dtype=np.int16).astype(np.float32) / 32768.0
                                elif _fmt == pyaudio.paInt32:
                                    audio = np.frombuffer(in_data, dtype=np.int32).astype(np.float32) / 2147483648.0
                                else:
                                    audio = np.frombuffer(in_data, dtype=np.float32)

                                if _ch > 1:
                                    n = len(audio) // _ch
                                    if n > 0:
                                        audio = audio[:n * _ch].reshape(n, _ch).mean(axis=1)
                                rms = float(np.sqrt(np.mean(audio ** 2))) if len(audio) > 0 else 0.0
                                self.audio_level = rms * 10  # GIL-safe float assignment
                                if self.is_recording:
                                    # Put mono float32 bytes so VAD gets clean mono
                                    self.audio_queue.put(audio.astype(np.float32).tobytes())
                            return (in_data, pyaudio.paContinue)

                        stream = p.open(
                            format=fmt,
                            channels=current_channels,
                            rate=rate,
                            input=True,
                            input_device_index=wanted_idx,
                            frames_per_buffer=0,
                            stream_callback=cb
                        )
                        dev_name = dev_info["name"][:30]
                        self.after(0, self._set_audio_status,
                                   f"READY ({dev_name} | {current_channels}ch | {rate}Hz)")
                    except Exception as e:
                        current_idx = -2  # force retry next loop
                        self.after(0, self._set_audio_status, f"ERROR ({e})")

            if not self.is_recording:
                time.sleep(0.05)
                buffer.clear()
                speech_started = False
                silence_frames = 0
                wait_frames = 0
                continue

            try:
                chunk = self.audio_queue.get(timeout=0.1)
            except queue.Empty:
                continue
            except Exception as e:
                self.log_diagnostic(f"THREAD CRASH in queue get: {traceback.format_exc()}")
                continue
                
            try:
                audio_data = np.frombuffer(chunk, dtype=np.float32)
                
                raw_rms = float(np.sqrt(np.mean(audio_data ** 2)))
                raw_rms_db = 20 * np.log10(raw_rms + 1e-6)
                samplerate = rate
                channels = current_channels

                if self.state in [AppState.WAITING_FOR_FIRST_SPEECH, AppState.IN_SPEECH]:
                    if len(audio_data.shape) > 1:
                        mono = np.mean(audio_data, axis=1)
                    else:
                        mono = audio_data.flatten()
                        
                    if samplerate == 48000:
                        audio_16k = mono[::3]
                    elif samplerate != 16000:
                        num_samples = int(len(mono) * 16000 / samplerate)
                        audio_16k = scipy.signal.resample(mono, num_samples)
                    else:
                        audio_16k = mono
                        
                    if hasattr(self, 'current_debug_wav_frames'):
                        self.current_debug_wav_frames.append(audio_16k.astype(np.float32))
                        
                    if not hasattr(self, 'vad_fifo'):
                        self.vad_fifo = []
                        
                    self.vad_fifo.extend(audio_16k.tolist())

                    while len(self.vad_fifo) >= 512:
                        block = np.array(self.vad_fifo[:512], dtype=np.float32)
                        self.vad_fifo = self.vad_fifo[512:]
                        
                        resampled_rms = float(np.sqrt(np.mean(block ** 2)))
                        resampled_rms_db = 20 * np.log10(resampled_rms + 1e-6)

                        try:
                            speech_prob = self.vad_model(torch.from_numpy(block).unsqueeze(0), 16000).item()
                        except:
                            speech_prob = 0.0

                        if hasattr(self, 'call_stats'):
                            self.call_stats["max_vad_prob"] = max(self.call_stats["max_vad_prob"], speech_prob)
                            self.call_stats["max_raw_db"] = max(self.call_stats["max_raw_db"], raw_rms_db)
                            self.call_stats["max_resampled_db"] = max(self.call_stats["max_resampled_db"], resampled_rms_db)

                        is_speech_now = speech_prob >= 0.05
                        
                        if wait_frames % 6 == 0 or silence_frames % 6 == 0:
                            self.log_diagnostic(f"state={self.state} raw={raw_rms_db:.1f}dB raw_rate={samplerate} resampled={resampled_rms_db:.1f}dB vad_prob={speech_prob:.4f} speech={'YES' if is_speech_now else 'NO'}")

                        if is_speech_now:
                            if not speech_started:
                                self.log_diagnostic(f"FIRST_SPEECH_DETECTED vad_prob={speech_prob:.4f}")
                                self.log_diagnostic("WAITING_FOR_FIRST_SPEECH -> IN_SPEECH")
                                speech_started = True
                                self.set_state(AppState.IN_SPEECH)
                                if not hasattr(self, 'buffer_48k'): self.buffer_48k = []
                                self.buffer_48k.clear()
                                self.last_partial_time = time.time()
                            silence_frames = 0
                            buffer.append(block)
                            if hasattr(self, 'buffer_48k'):
                                self.buffer_48k.extend(mono_48k_chunk.tolist() if 'mono_48k_chunk' in locals() else [])
                            
                            # Send to partial ASR every 1.0 second
                            if time.time() - getattr(self, 'last_partial_time', 0) > 1.0:
                                self.last_partial_time = time.time()
                                if hasattr(self, 'buffer_48k') and len(self.buffer_48k) > 0:
                                    b48 = np.array(self.buffer_48k, dtype=np.float32)
                                    b16 = scipy.signal.resample(b48, int(len(b48) * 16000 / samplerate)) if samplerate != 16000 else b48
                                    self.partial_asr_queue.put(b16)
                                    
                        else:
                            if speech_started:
                                silence_frames += 1
                                buffer.append(block)
                                if hasattr(self, 'buffer_48k'):
                                    self.buffer_48k.extend(mono_48k_chunk.tolist() if 'mono_48k_chunk' in locals() else [])
                                    
                                if silence_frames > (VAD_SILENCE_MS / 1000.0) * CHUNKS_PER_SEC:
                                    self.log_diagnostic("IN_SPEECH -> ENDPOINTING")
                                    self.is_recording = False
                                    self.set_state(AppState.ENDPOINTING)
                                    self.save_debug_wav()
                                    
                                    # Use the high-quality 48k buffer for final ASR
                                    if hasattr(self, 'buffer_48k') and len(self.buffer_48k) > 0:
                                        b48 = np.array(self.buffer_48k, dtype=np.float32)
                                        final_audio = scipy.signal.resample(b48, int(len(b48) * 16000 / samplerate)) if samplerate != 16000 else b48
                                    else:
                                        final_audio = np.concatenate(buffer)
                                        
                                    self.process_asr(final_audio)
                                    break
                            else:
                                wait_frames += 1
                                if wait_frames > (FIRST_SPEECH_TIMEOUT_MS / 1000.0) * CHUNKS_PER_SEC:
                                    self.log_diagnostic("FIRST_SPEECH_TIMEOUT")
                                    self.is_recording = False
                                    self.set_state(AppState.RESULT)
                                    self.save_debug_wav()
                                    self.after(0, lambda: self.txt_client.insert(tk.END, "[ТИШИНА 15 СЕКУНД]"))
                                    self.process_decision("")
                                    break
            except Exception as e:
                self.log_diagnostic(f"THREAD CRASH in main loop: {traceback.format_exc()}")
            except queue.Empty:
                pass
                
        if stream is not None:
            try:
                stream.stop_stream()
                stream.close()
            except Exception:
                pass
        
        p.terminate()
        pythoncom.CoUninitialize()

    def partial_asr_worker(self):
        while self.audio_thread_active:
            try:
                audio_np = self.partial_asr_queue.get(timeout=1.0)
                
                # SMART DROP: Drain the queue to always get the FRESHEST audio chunk, eliminating backlog latency!
                while not self.partial_asr_queue.empty():
                    try:
                        audio_np = self.partial_asr_queue.get_nowait()
                    except queue.Empty:
                        break
                        
                if self.state != AppState.IN_SPEECH: continue
                
                segments, _ = self.whisper_model.transcribe(
                    audio_np, beam_size=1, language="uk", condition_on_previous_text=False, vad_filter=False
                )
                text = " ".join([s.text for s in segments]).strip()
                if text:
                    self.after(0, lambda t=text: self._update_live_transcript(t))
            except:
                pass
                
    def _update_live_transcript(self, text):
        if self.state == AppState.IN_SPEECH:
            self.txt_client.delete(1.0, tk.END)
            self.txt_client.insert(tk.END, text + "...")

    def process_asr(self, audio_np):
        self.set_state(AppState.ASR_DECISION)
        
        self.log_diagnostic("ASR_START")
        start_t = time.time()
        
        try:
            segments, _ = self.whisper_model.transcribe(
                audio_np, beam_size=3, language="uk", condition_on_previous_text=False, vad_filter=False
            )
            text = " ".join([s.text for s in segments]).strip()
        except Exception as e:
            text = f"[ASR ERROR: {e}]"
            
        self.after(0, lambda: self.txt_client.delete(1.0, tk.END))
        self.after(0, lambda: self.txt_client.insert(tk.END, text))
        self.process_decision(text)

    def process_decision(self, text):
        decision, _ = classify(text)
        color = "#f38ba8" if decision == "negative" else "#a6e3a1" if decision == "positive" else "#f9e2af"
        self.after(0, lambda: self.lbl_decision.config(text=decision.upper(), foreground=color))
        self.set_state(AppState.RESULT)
        
        # Add to review queue
        result = {
            "phone": self.current_phone,
            "text": text,
            "decision": decision,
            "color": color
        }
        self.review_queue.append(result)
        self.update_review_ui()
        
        # Do not automatically hang up here.
        # The user will press X to play closing message and hang up,
        # or they will manually talk and hang up later.
        
    def update_review_ui(self):
        if not self.review_queue:
            self.frame_review.config(text="ОЦЕНКА ЗВОНКОВ (Очередь: 0)")
            self.lbl_rev_phone.config(text="Номер: ---")
            self.txt_rev_client.delete(1.0, tk.END)
            self.lbl_rev_decision.config(text="---", foreground="#a6e3a1")
        else:
            item = self.review_queue[0]
            self.frame_review.config(text=f"ОЦЕНКА ЗВОНКОВ (Очередь: {len(self.review_queue)})")
            self.lbl_rev_phone.config(text=f"Номер: {item['phone']}")
            self.txt_rev_client.delete(1.0, tk.END)
            self.txt_rev_client.insert(tk.END, item['text'])
            self.lbl_rev_decision.config(text=item['decision'].upper(), foreground=item['color'])

    def save_result(self, rating=None, manual_decision=None):
        if not self.review_queue: return
        item = self.review_queue.pop(0)
        
        # Save to CSV
        try:
            file_exists = os.path.exists("calls_log.csv")
            with open("calls_log.csv", "a", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                if not file_exists:
                    writer.writerow(["Time", "Phone", "Transcript", "AI Decision", "Rating", "Manual Decision"])
                writer.writerow([
                    datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    item['phone'],
                    item['text'],
                    item['decision'],
                    rating if rating else "",
                    manual_decision if manual_decision else ""
                ])
        except Exception as e:
            print(f"Failed to write CSV log: {e}")
            
        print(f"Logged review for {item['phone']}: rating={rating} manual={manual_decision}")
        self.update_review_ui()
        
    def trigger_delayed_hangup(self):
        if self.state != AppState.IDLE:
            self.action_hangup()
            self.action_next()
            if getattr(self, 'auto_calling', False):
                self.after(1500, self.auto_next_call)

    def on_global_x_pressed(self, event):
        if self.review_queue:
            self.after(0, lambda: self.save_result(manual_decision="POSITIVE"))
            
        # Start a 4s timer to hang up the live call and move to next
        if getattr(self, 'delayed_hangup_timer', None):
            self.after_cancel(self.delayed_hangup_timer)
        self.delayed_hangup_timer = self.after(4000, self.trigger_delayed_hangup)

    def on_closing(self):
        self.audio_thread_active = False
        self.destroy()

if __name__ == "__main__":
    import traceback
    try:
        app = MicroSIPAssistantApp()
        app.mainloop()
    except Exception as e:
        with open("crash.log", "w") as f:
            f.write(traceback.format_exc())
        
        # We might need to initialize a hidden Tk window just for messagebox if it crashed before init
        root = tk.Tk()
        root.withdraw()
        messagebox.showerror("Crash", traceback.format_exc())
