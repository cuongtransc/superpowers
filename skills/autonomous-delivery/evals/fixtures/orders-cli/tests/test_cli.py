from orders import cli


def test_show_prints_order(capsys):
    assert cli.main(["show", "1001"]) == 0
    assert capsys.readouterr().out.strip() == "1001 paid 1250"


def test_show_unknown_id(capsys):
    assert cli.main(["show", "9999"]) == 1
    assert capsys.readouterr().err.strip() == "order not found: 9999"
