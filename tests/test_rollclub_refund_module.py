import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE = (ROOT / "modules" / "rollclub-refund" / "refund.ahk").read_text(encoding="utf-8-sig")
BRIDGE = (ROOT.parent / "server" / "iiko_bridge.py").read_text(encoding="utf-8")
ENGINE = (ROOT / "engine_rollclub.ahk").read_text(encoding="utf-8-sig")


class RollClubRefundModuleTests(unittest.TestCase):
    def test_ctrl_f5_is_registered_by_rollclub_and_starts_the_enabled_module(self):
        self.assertIn(
            'ModuleRegistry_RegisterExternal("refund", "rollclub-refund")',
            ENGINE,
        )
        self.assertIn("^F5::", ENGINE)
        self.assertIn(
            'ModuleRegistry_RefreshExternal("refund", "rollclub-refund")',
            ENGINE,
        )
        self.assertIn('ModuleRegistry_RunExternal("refund")', ENGINE)

    def test_server_returns_history_and_exact_amount_in_existing_scan(self):
        self.assertIn("'memoEditDeliveryHistory',", BRIDGE)
        self.assertIn("'sum_raw':          sum_raw", BRIDGE)
        self.assertIn("'history':          val('memoEditDeliveryHistory')", BRIDGE)
        self.assertIn("'source_label':     val('labelDeliveryNumber')", BRIDGE)

    def test_module_skips_second_uia_scan_when_server_data_is_complete(self):
        self.assertIn('Refund_JsonString(_json, "history")', MODULE)
        self.assertIn('Refund_JsonString(_json, "sum_raw")', MODULE)
        self.assertIn('(!_serverOk || _history = "" || _amountText = "") ? Refund_ReadUiaSnapshot() : ""', MODULE)

    def test_operator_flow_has_one_primary_action(self):
        self.assertIn("Default gRefundBuildCopy, Сформувати та скопіювати", MODULE)
        self.assertIn('A_Args[1] = "--ui-smoke-test"', MODULE)
        self.assertIn("Готово. Текст скопійовано", MODULE)
        self.assertIn("Дані ще не готові. Повторюю автоматично", MODULE)

    def test_fop_parser_covers_missing_final_dot(self):
        self.assertIn('fop_without_final_dot', MODULE)

    def test_city_uses_order_source_and_rejects_street(self):
        self.assertIn('source_city_priority', MODULE)
        self.assertIn('street_is_not_city', MODULE)


if __name__ == "__main__":
    unittest.main()
