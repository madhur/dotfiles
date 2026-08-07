#!/usr/bin/env python3
"""Unit tests for loan_prepayment_digest.py.

Plain assert-based tests, PASS/FAIL runner — same convention as
tests/test-idle-alert-lib.sh, translated to Python. No pytest dependency.
Run directly: python3 ~/scripts/tests/test_loan_prepayment_digest.py

Pure-logic functions only (find_loan_account, compute_scenarios, build_email,
build_ntfy_message) are tested here — no live Firefly/Mailpit/ntfy calls.
Importing loan_prepayment_digest is safe: its module-level code only loads
.env files, it makes no network calls until main() runs.
"""
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import loan_prepayment_digest as lpd

FAILURES = 0


def run_test(name, fn):
    global FAILURES
    try:
        fn()
        print(f"PASS: {name}")
    except AssertionError as e:
        print(f"FAIL: {name}: {e}")
        FAILURES += 1
    except Exception as e:
        print(f"FAIL: {name}: unexpected {type(e).__name__}: {e}")
        FAILURES += 1


def test_find_loan_account_matches_by_substring():
    accounts = [
        {"attributes": {"name": "HDFC Savings ...9756"}},
        {"attributes": {"name": "SBI Loan ...5256"}},
    ]
    result = lpd.find_loan_account(accounts, "SBI Loan")
    assert result["attributes"]["name"] == "SBI Loan ...5256"


def test_find_loan_account_matches_case_insensitively():
    accounts = [{"attributes": {"name": "sbi loan ...5256"}}]
    result = lpd.find_loan_account(accounts, "SBI Loan")
    assert result["attributes"]["name"] == "sbi loan ...5256"


def test_find_loan_account_raises_on_zero_matches():
    accounts = [{"attributes": {"name": "HDFC Savings ...9756"}}]
    try:
        lpd.find_loan_account(accounts, "SBI Loan")
        assert False, "expected ValueError"
    except ValueError:
        pass


def test_find_loan_account_raises_on_multiple_matches():
    accounts = [
        {"attributes": {"name": "SBI Loan ...5256"}},
        {"attributes": {"name": "SBI Loan ...9999"}},
    ]
    try:
        lpd.find_loan_account(accounts, "SBI Loan")
        assert False, "expected ValueError"
    except ValueError as e:
        assert "2" in str(e)


FIXTURE_CFG = {
    "rate": 7.5,
    "emi": 136951,
    "original_principal": 17000000,
    "original_rate": 7.5,
    "original_months": 240,
    "original_start": date(2026, 4, 5),
}


def test_compute_scenarios_infers_pace_and_projects():
    # Fixture validated against two independent manual runs of
    # prepayment_simulator.py earlier in this project (outstanding=1.6cr,
    # today=05/08/2026): elapsed=4 EMIs, inferred pace Rs 2,19,010/month.
    r = lpd.compute_scenarios(16000000, date(2026, 8, 5), FIXTURE_CFG)
    assert r["elapsed_months"] == 4
    assert r["pace_known"] is True
    assert r["monthly_prepay"] == 219010
    assert r["baseline_months"] == 211
    assert r["baseline_close_date"] == date(2044, 2, 5)
    assert r["baseline_interest"] == 12795303
    assert r["projected_months"] == 53
    assert r["projected_close_date"] == date(2030, 12, 5)
    assert r["projected_interest"] == 2841832
    assert r["extra_prepaid"] == 11583429
    assert r["interest_saved"] == 9953471


def test_compute_scenarios_falls_back_when_no_pace_detectable():
    # outstanding == the no-prepayment baseline balance after 4 EMIs exactly
    # -> zero prepayment inferred -> infer_monthly_prepay raises -> caught.
    r = lpd.compute_scenarios(16876040, date(2026, 8, 5), FIXTURE_CFG)
    assert r["pace_known"] is False
    assert r["monthly_prepay"] == 0
    assert r["projected_months"] == r["baseline_months"]
    assert r["projected_interest"] == r["baseline_interest"]
    assert r["extra_prepaid"] == 0
    assert r["interest_saved"] == 0


def _fixture_result(pace_known=True):
    if pace_known:
        return lpd.compute_scenarios(16000000, date(2026, 8, 5), FIXTURE_CFG)
    return lpd.compute_scenarios(16876040, date(2026, 8, 5), FIXTURE_CFG)


def test_build_email_pace_known():
    r = _fixture_result(pace_known=True)
    subject, plain, html = lpd.build_email(r, "07 Aug 09:00 IST")
    assert "1,60,00,000" in subject
    assert "1,60,00,000" in plain
    assert "2,19,010" in plain or "2,19,010" in html
    assert "Continuing current pace" in html
    assert "No further prepayment" in html
    assert "12,795,303" not in html  # sanity: not using unformatted digit grouping
    assert "1,27,95,303" in html
    assert "28,41,832" in html


def test_build_email_pace_unknown_omits_projection_row():
    r = _fixture_result(pace_known=False)
    subject, plain, html = lpd.build_email(r, "07 Aug 09:00 IST")
    assert "No prepayment pace detected" in html
    assert "Continuing current pace" not in html


def test_build_ntfy_message_pace_known():
    r = _fixture_result(pace_known=True)
    title, body = lpd.build_ntfy_message(r)
    assert "closes" in title.lower()
    assert "2,19,010" in body
    assert "1,60,00,000" in body


def test_build_ntfy_message_pace_unknown():
    r = _fixture_result(pace_known=False)
    title, body = lpd.build_ntfy_message(r)
    assert "no prepayment pace detected" in body.lower()


if __name__ == "__main__":
    run_test("find_loan_account matches by substring", test_find_loan_account_matches_by_substring)
    run_test("find_loan_account matches case-insensitively", test_find_loan_account_matches_case_insensitively)
    run_test("find_loan_account raises on zero matches", test_find_loan_account_raises_on_zero_matches)
    run_test("find_loan_account raises on multiple matches", test_find_loan_account_raises_on_multiple_matches)
    run_test("compute_scenarios infers pace and projects", test_compute_scenarios_infers_pace_and_projects)
    run_test("compute_scenarios falls back with no pace", test_compute_scenarios_falls_back_when_no_pace_detectable)
    run_test("build_email includes key figures (pace known)", test_build_email_pace_known)
    run_test("build_email omits projection row (pace unknown)", test_build_email_pace_unknown_omits_projection_row)
    run_test("build_ntfy_message includes key figures (pace known)", test_build_ntfy_message_pace_known)
    run_test("build_ntfy_message notes unknown pace", test_build_ntfy_message_pace_unknown)
    print(f"\n{FAILURES} failure(s)" if FAILURES else "\nAll tests passed")
    sys.exit(1 if FAILURES else 0)
