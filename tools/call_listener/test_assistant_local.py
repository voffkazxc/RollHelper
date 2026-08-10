import threading
import time
import os

# Stub os.system to prevent actual calls
original_system = os.system
def dummy_system(cmd):
    print(f"[STUB] Blocked os.system: {cmd}")
os.system = dummy_system

import microsip_assistant

def auto_tester(app):
    print("\nWaiting for app to initialize...")
    time.sleep(3)
    
    print("\nSimulating incoming UDP trigger for dummy number...")
    app.current_phone = "00000"
    app.action_call()
    
    print("\nApp is now 'calling'. PLEASE PLAY YOUTUBE NOW!")
    print("Monitoring state transitions for 15 seconds...\n")
    
    for i in range(150):
        time.sleep(0.1)
        if app.state == microsip_assistant.AppState.IN_SPEECH:
            print(f"\n[SUCCESS] App correctly transitioned to IN_SPEECH at {i/10.0}s!")
            print(f"Max VAD Prob seen: {app.call_stats.get('max_vad_prob', 0):.4f}")
            print("Test passed. Closing app...")
            app.after(0, app.on_closing)
            return
            
    print("\n[FAIL] App never transitioned to IN_SPEECH within 15 seconds.")
    app.after(0, app.on_closing)

if __name__ == "__main__":
    app = microsip_assistant.MicrosipAssistant()
    
    t = threading.Thread(target=auto_tester, args=(app,))
    t.daemon = True
    t.start()
    
    app.mainloop()
