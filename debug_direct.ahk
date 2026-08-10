#Requires AutoHotkey v1.1
#NoEnv

logPath := "C:\Users\voffk\.gemini\antigravity\brain\cf43b635-3e88-44b4-b712-7e3e8969ed91\scratch\order_items_result.txt"
FileDelete, %logPath%
FileAppend, HELLO FROM AHK NON CYRILLIC PATH`n, %logPath%
