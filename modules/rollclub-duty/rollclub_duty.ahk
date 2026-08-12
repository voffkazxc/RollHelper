#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
#Persistent
SendMode Input
SetWorkingDir %A_ScriptDir%

EnvGet, RcDutyTargetHwnd, ROLLHELPER_ROLLCLUB_DUTY_HWND
if (RcDutyTargetHwnd = "") {
    MsgBox, 48, Дежурство заказов, Спочатку запустіть RollClub через RollHelper Launcher.
    ExitApp
}

OnExit, RcDutyExit
TrayTip, RollClub, Доповнення «Дежурство заказов» увімкнено. F4 — старт або стоп., 2, 1
return

F4::RcDutySendToggle()

RcDutySendToggle() {
    global RcDutyTargetHwnd

    if !WinExist("ahk_id " . RcDutyTargetHwnd) {
        TrayTip, RollClub, Базовий RollClub не запущено. Запустіть його через лаунчер., 3, 2
        return
    }

    PostMessage, 0x8001, 1, 0,, ahk_id %RcDutyTargetHwnd%
}

RcDutyExit:
return
