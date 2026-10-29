# Run from td_project. Load through TD's GUI run-parameter path, not settings.cfg.
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project wb_ui_dsi.al -single_run
load_run_param -run syn_1
commit_param -step gate
report_param -stage gate -detail
load_run_param -run phy_1
commit_param -step place
commit_param -step route
report_param -stage place -detail
report_param -stage route -detail
exit
